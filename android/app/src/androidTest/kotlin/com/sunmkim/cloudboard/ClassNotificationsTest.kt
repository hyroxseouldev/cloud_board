package com.sunmkim.cloudboard

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class ClassNotificationsTest {
    private fun eventually(predicate: () -> Boolean) {
        val deadline = android.os.SystemClock.elapsedRealtime() + 2000
        while (!predicate() && android.os.SystemClock.elapsedRealtime() < deadline) Thread.sleep(20)
        assertTrue(predicate())
    }
    @Test fun deniedPermissionDoesNotCrashOrPublish() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val manager = context.getSystemService(NotificationManager::class.java)
        // Run this case after adb shell pm revoke ... POST_NOTIFICATIONS.
        org.junit.Assume.assumeFalse(manager.areNotificationsEnabled())
        val config = JSONObject("""{"ownerId":"test-owner","sessionId":"denied","deviceId":"test","workoutName":"권한 거부 검증","status":"paused","revision":1,"stepIndex":0,"remainingMs":1000,"anchorServerMs":0,"steps":[{"name":"운동","durationMs":1000,"label":"운동"}]}""")
        try {
            instrumentation.runOnMainSync { ClassNotifications.project(context, config) }
            eventually { manager.activeNotifications.none { it.id == 4601 } }
        } finally { instrumentation.runOnMainSync { ClassNotifications.clear(context) } }
    }

    @Test fun ordinaryNotificationOffersAllControlsAndClearsOnEnd() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        if (Build.VERSION.SDK_INT >= 33) instrumentation.uiAutomation.grantRuntimePermission(context.packageName, Manifest.permission.POST_NOTIFICATIONS)
        val manager = context.getSystemService(NotificationManager::class.java)
        val config = JSONObject("""{"ownerId":"test-owner","sessionId":"instrumentation-only","deviceId":"test","workoutName":"알림 제어 자동 검증","status":"paused","revision":1,"stepIndex":0,"remainingMs":60000,"anchorServerMs":0,"connected":true,"steps":[{"name":"스쿼트","durationMs":60000,"label":"운동 · 1/1세트"}]}""")
        try {
            instrumentation.runOnMainSync { ClassNotifications.project(context, config) }
            eventually { manager.activeNotifications.any { it.id == 4601 } }
            val notification = manager.activeNotifications.single { it.id == 4601 }.notification
            assertEquals(R.drawable.ic_class_notification, notification.smallIcon.resId)
            assertEquals("알림 제어 자동 검증", notification.extras.getString(Notification.EXTRA_TITLE))
            assertTrue(notification.extras.getString(Notification.EXTRA_TEXT)!!.startsWith("스쿼트 · 일시정지"))
            assertEquals("최근 수업", notification.extras.getString(Notification.EXTRA_SUB_TEXT))
            assertEquals(3, notification.actions.size) // Previous/resume/next in compact standard actions.
            if (Build.VERSION.SDK_INT >= 36) {
                assertNull(notification.bigContentView)
                assertNull(notification.contentView)
                assertTrue(notification.flags and Notification.FLAG_ONGOING_EVENT != 0)
                assertTrue(notification.hasPromotableCharacteristics())
            } else {
                assertNotNull(notification.bigContentView) // Legacy expanded layout includes stop.
            }
            assertTrue(notification.timeoutAfter in 1..900000)
            instrumentation.runOnMainSync { ClassNotifications.project(context, config.put("connected", false)) }
            eventually {
                manager.activeNotifications.single { it.id == 4601 }.notification
                    .extras.getString(Notification.EXTRA_SUB_TEXT) == "연결 확인 필요"
            }
            val offline = manager.activeNotifications.single { it.id == 4601 }.notification
            assertFalse(offline.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
            assertEquals(3, offline.actions.size) // Actions still confirm state before any write.
            // Old/forged action tokens terminate immediately without invoking any network command.
            val done = CountDownLatch(1)
            ClassNotifications.receive(context, Intent().putExtra("sessionId", "instrumentation-only").putExtra("token", "stale").putExtra("command", "next")) { done.countDown() }
            assertTrue(done.await(1, TimeUnit.SECONDS))
            assertEquals(1, JSONObject(context.getSharedPreferences("class_controls", Context.MODE_PRIVATE).getString("config", "")!!).getInt("revision"))
            instrumentation.runOnMainSync { ClassNotifications.project(context, config.put("status", "completed")) }
            eventually { manager.activeNotifications.none { it.id == 4601 } }
        } finally { instrumentation.runOnMainSync { ClassNotifications.clear(context) } }
    }

    @Test fun liveUpdateTemplateUsesSystemCountdownAndPauses() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        fun render(paused: Boolean, confirmed: Boolean): Notification {
            val builder = NotificationCompat.Builder(context, "class_controls_v1")
                .setSmallIcon(android.R.drawable.ic_media_play).setContentTitle("수업")
                .setStyle(NotificationCompat.BigTextStyle().bigText("예상 남은 시간"))
            ClassLiveUpdate.apply(builder, 90_000, paused, confirmed, now = 1_000_000)
            return builder.build()
        }
        val playing = render(paused = false, confirmed = true)
        assertEquals(1_090_000L, playing.`when`)
        assertTrue(playing.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(playing.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
        assertTrue(playing.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertNull(playing.contentView)
        assertNull(playing.bigContentView)
        val paused = render(paused = true, confirmed = true)
        assertFalse(paused.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertEquals(0L, paused.`when`)
        val offline = render(paused = false, confirmed = false)
        assertFalse(offline.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertEquals(0, offline.flags and Notification.FLAG_ONGOING_EVENT)
        assertEquals("1:30", ClassLiveUpdate.remainingText(89_001))
        assertEquals("0:00", ClassLiveUpdate.remainingText(-1))
        if (Build.VERSION.SDK_INT >= 36) {
            assertTrue(playing.hasPromotableCharacteristics())
            assertFalse(offline.hasPromotableCharacteristics())
        }
    }

    @Test fun dismissedSessionStaysHiddenUntilANewClassStarts() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        if (Build.VERSION.SDK_INT >= 33) instrumentation.uiAutomation.grantRuntimePermission(context.packageName, Manifest.permission.POST_NOTIFICATIONS)
        val manager = context.getSystemService(NotificationManager::class.java)
        val config = JSONObject("""{"ownerId":"test-owner","sessionId":"dismiss-test","deviceId":"test","workoutName":"숨기기 검증","status":"paused","revision":1,"stepIndex":0,"remainingMs":60000,"anchorServerMs":0,"connected":true,"steps":[{"name":"운동","durationMs":60000,"label":"운동"}]}""")
        try {
            instrumentation.runOnMainSync { ClassNotifications.project(context, config) }
            eventually { manager.activeNotifications.any { it.id == 4601 } }
            val notification = manager.activeNotifications.single { it.id == 4601 }.notification
            assertNotNull(notification.deleteIntent)
            notification.deleteIntent.send()
            eventually { manager.activeNotifications.none { it.id == 4601 } }
            instrumentation.runOnMainSync { ClassNotifications.project(context, config.put("revision", 2)) }
            assertTrue(manager.activeNotifications.none { it.id == 4601 })
            assertEquals("paused", JSONObject(context.getSharedPreferences("class_controls", Context.MODE_PRIVATE).getString("config", "")!!).getString("status"))
            instrumentation.runOnMainSync { ClassNotifications.project(context, config.put("sessionId", "new-class")) }
            eventually { manager.activeNotifications.any { it.id == 4601 } }
            instrumentation.runOnMainSync { ClassNotifications.dismiss(context, "dismiss-test") }
            assertTrue(manager.activeNotifications.any { it.id == 4601 })
        } finally { instrumentation.runOnMainSync { ClassNotifications.clear(context) } }
    }
}
