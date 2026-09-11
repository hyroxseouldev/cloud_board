package com.sunmkim.cloudboard

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
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
            assertEquals(3, notification.actions.size) // Previous/resume/next in compact standard actions.
            assertNotNull(notification.bigContentView) // Expanded custom layout also includes stop.
            assertTrue(notification.timeoutAfter in 1..900000)
            // Old/forged action tokens terminate immediately without invoking any network command.
            val done = CountDownLatch(1)
            ClassNotifications.receive(context, Intent().putExtra("sessionId", "instrumentation-only").putExtra("token", "stale").putExtra("command", "next")) { done.countDown() }
            assertTrue(done.await(1, TimeUnit.SECONDS))
            assertEquals(1, JSONObject(context.getSharedPreferences("class_controls", Context.MODE_PRIVATE).getString("config", "")!!).getInt("revision"))
            instrumentation.runOnMainSync { ClassNotifications.project(context, config.put("status", "completed")) }
            eventually { manager.activeNotifications.none { it.id == 4601 } }
        } finally { instrumentation.runOnMainSync { ClassNotifications.clear(context) } }
    }
}
