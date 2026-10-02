package com.sunmkim.cloudboard

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** Class notifications, promoted on Android 16+: no media session or foreground service. */
internal object ClassNotifications {
    private const val CHANNEL = "class_controls_v1"
    private const val ID = 4601
    internal const val DISMISS = "com.sunmkim.cloudboard.DISMISS_CLASS_NOTIFICATION"
    private const val DATABASE = "https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app"
    private val busy = AtomicBoolean(false)
    private val executor = Executors.newSingleThreadExecutor()
    private val deadlines = Executors.newSingleThreadScheduledExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var boundary: Runnable? = null
    private fun prefs(context: Context) = context.getSharedPreferences("class_controls", Context.MODE_PRIVATE)
    private fun manager(context: Context) = NotificationManagerCompat.from(context)

    fun install(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "com.sunmkim.cloudboard/class_controls").setMethodCallHandler { call, result ->
            when (call.method) {
                "clear" -> { clear(activity); result.success(null) }
                "show" -> {
                    try {
                        val config = JSONObject(call.arguments as String)
                        val old = load(activity)
                        // Ignore stale Flutter projections while a newer native command settles.
                        if (old?.optString("sessionId") == config.getString("sessionId") &&
                            old.optLong("revision") > config.getLong("revision")) {
                            result.success(manager(activity).areNotificationsEnabled())
                        } else {
                            project(activity, config)
                            explainPermission(activity)
                            result.success(manager(activity).areNotificationsEnabled())
                        }
                    } catch (_: Exception) { result.error("notification", "수업 알림을 갱신하지 못했습니다", null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    internal fun project(context: Context, config: JSONObject) {
        prefs(context).edit().putString("config", config.toString()).apply()
        show(context, config)
    }

    fun permissionGranted(context: Context) { load(context)?.let { show(context, it) } }

    private fun explainPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT < 33 || activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED || prefs(activity).getBoolean("asked", false)) return
        prefs(activity).edit().putBoolean("asked", true).apply()
        AlertDialog.Builder(activity).setTitle("수업 제어 알림")
            .setMessage("홈 화면이나 다른 앱에서도 연결된 수업을 제어하려면 알림을 허용해 주세요. 허용하지 않아도 앱 안에서는 계속 제어할 수 있습니다.")
            .setNegativeButton("나중에", null)
            .setPositiveButton("계속") { _, _ -> activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4601) }
            .show()
    }

    @Synchronized fun clear(context: Context) {
        prefs(context).edit().remove("config").remove("token").remove("dismissedSession").apply()
        boundary?.let { main.removeCallbacks(it) }
        boundary = null
        manager(context).cancel(ID)
    }

    private fun load(context: Context): JSONObject? = prefs(context).getString("config", null)?.let { JSONObject(it) }

    @Synchronized fun dismiss(context: Context, sessionId: String?) {
        if (sessionId == null || load(context)?.optString("sessionId") != sessionId) return
        // Dismissing the card only hides this session; it never stops the class.
        prefs(context).edit().putString("dismissedSession", sessionId).remove("token").apply()
        boundary?.let { main.removeCallbacks(it) }
        boundary = null
        manager(context).cancel(ID)
    }

    @Synchronized private fun show(context: Context, config: JSONObject, error: String? = null) {
        val now = System.currentTimeMillis() + config.optLong("serverOffsetMs")
        val position = ClassCommand.position(config, config, now)
        val steps = config.getJSONArray("steps")
        if (position.index >= steps.length() || config.getString("status") == "completed") { clear(context); return }
        if (prefs(context).getString("dismissedSession", null) == config.getString("sessionId")) return
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "진행 중인 수업 제어", NotificationManager.IMPORTANCE_LOW)
            channel.description = "연결된 디스플레이 수업의 상태 확인 및 제어"
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val token = UUID.randomUUID().toString()
        prefs(context).edit().putString("token", token).apply()
        val open = PendingIntent.getActivity(context, ID, Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val step = steps.getJSONObject(position.index)
        val paused = config.getString("status") == "paused"
        val connected = config.optBoolean("connected", true)
        val useLiveUpdate = Build.VERSION.SDK_INT >= 36
        var untilEnd = position.remaining + position.countdown
        for (i in position.index + 1 until steps.length()) untilEnd += steps.getJSONObject(i).getLong("durationMs")
        val label = if (paused) "일시정지" else step.getString("label")
        val text = error ?: if (!connected) "연결 확인 필요 · 앱에서 다시 연결해 주세요"
            else "${step.getString("name")} · $label" +
                if (useLiveUpdate && paused) " · 남음 ${ClassLiveUpdate.remainingText(untilEnd)}" else ""
        // A projected countdown is an estimate, not a continuous server confirmation.
        val subText = if (error != null) "상태 확인 필요" else if (!connected) "연결 확인 필요"
            else if (useLiveUpdate && !paused) "예상 남은 시간" else "최근 수업"
        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_class_notification).setColor(0xFF77729D.toInt())
            .setContentTitle(config.getString("workoutName"))
            .setContentText(text).setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSubText(subText)
            .setContentIntent(open).setOnlyAlertOnce(true).setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setOngoing(false)
        val dismiss = Intent(context, ClassControlReceiver::class.java).setAction(DISMISS)
            .setData(Uri.parse("cloudboard-control://${config.getString("sessionId")}/dismiss"))
            .putExtra("sessionId", config.getString("sessionId"))
        builder.setDeleteIntent(PendingIntent.getBroadcast(context, 0, dismiss,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        val expanded = RemoteViews(context.packageName, R.layout.class_notification)
        expanded.setTextViewText(R.id.class_title, config.getString("workoutName"))
        expanded.setTextViewText(R.id.class_status, text)
        fun action(name: String, title: String, icon: Int) {
            val intent = Intent(context, ClassControlReceiver::class.java)
                .setData(Uri.parse("cloudboard-control://${config.getString("sessionId")}/$token/$name"))
                .putExtra("token", token).putExtra("sessionId", config.getString("sessionId"))
                .putExtra("command", name).addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            val pending = PendingIntent.getBroadcast(context, name.hashCode(), intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            if (name != "stop") builder.addAction(icon, title, pending)
            if (name == "stop") expanded.setOnClickPendingIntent(R.id.class_stop, pending)
        }
        if (error != null) {
            action("refresh", "상태 확인", android.R.drawable.ic_popup_sync)
        } else {
            action("previous", "이전", android.R.drawable.ic_media_previous)
            if (config.getString("status") == "paused") action("play", "재개", android.R.drawable.ic_media_play)
            else action("pause", "일시정지", android.R.drawable.ic_media_pause)
            action("next", "다음", android.R.drawable.ic_media_next)
            if (!useLiveUpdate) action("stop", "종료", android.R.drawable.ic_menu_close_clear_cancel)
        }
        if (useLiveUpdate) {
            ClassLiveUpdate.apply(builder, untilEnd, paused, connected && error == null)
        } else if (error == null) builder.setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomBigContentView(expanded)
        // Bound stale notifications after process eviction; paused sessions require reopening
        // after 15 minutes. No periodic service is kept alive just to refresh the clock.
        val lease = if (paused) 900000L else untilEnd.coerceIn(1L, 900000L)
        builder.setTimeoutAfter(lease)
        if (manager(context).areNotificationsEnabled()) {
            try { manager(context).notify(ID, builder.build()) } catch (_: SecurityException) { /* App controls remain available. */ }
        }
        boundary?.let { main.removeCallbacks(it) }
        if (error == null && config.getString("status") == "playing") {
            boundary = Runnable {
                val latest = load(context)
                if (latest?.optString("sessionId") == config.getString("sessionId") && latest.optLong("revision") == config.optLong("revision")) show(context, latest)
            }
            main.postDelayed(boundary!!, (position.remaining + position.countdown).coerceAtLeast(100L))
        }
    }

    fun receive(context: Context, intent: Intent, finish: () -> Unit) {
        val app = context.applicationContext
        val config = load(app)
        if (config == null || intent.getStringExtra("sessionId") != config.optString("sessionId") ||
            intent.getStringExtra("token") != prefs(app).getString("token", null) || !busy.compareAndSet(false, true)) { finish(); return }
        // Consume before I/O: duplicates and old PendingIntents cannot replay, even after restart.
        prefs(app).edit().remove("token").commit()
        val started = SystemClock.elapsedRealtime()
        executor.execute {
            try {
                execute(app, config, intent.getStringExtra("command") ?: "", started)
            } catch (_: Exception) {
                main.post {
                    val latest = load(app)
                    if (latest?.optString("sessionId") == config.optString("sessionId"))
                        show(app, latest, "명령 확인 실패 · 상태를 다시 확인해 주세요")
                }
            } finally { busy.set(false); finish() }
        }
    }

    private data class Response(val json: JSONObject, val etag: String?, val serverNow: Long)
    private fun request(path: String, token: String, deadline: Long, value: JSONObject? = null, etag: String? = null, conditional: Boolean = true): Response {
        val remaining = (deadline - SystemClock.elapsedRealtime()).coerceAtMost(2000).toInt()
        check(remaining > 0)
        val connection = URL("$DATABASE/$path.json?auth=${Uri.encode(token)}").openConnection() as HttpURLConnection
        val abort = deadlines.schedule({ connection.disconnect() }, remaining.toLong(), TimeUnit.MILLISECONDS)
        try {
            connection.connectTimeout = remaining; connection.readTimeout = remaining
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("X-Firebase-ETag", "true")
            if (value != null) {
                connection.requestMethod = "PUT"; connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                if (conditional) connection.setRequestProperty("if-match", requireNotNull(etag))
                connection.outputStream.use { it.write(value.toString().toByteArray(Charsets.UTF_8)) }
            }
            check(connection.responseCode == 200) { "Server did not confirm command" }
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            check(body != "null") { "Session ended" }
            val serverNow = connection.getHeaderFieldDate("Date", -1)
            check(serverNow > 0) { "Server clock unavailable" }
            return Response(JSONObject(body), connection.getHeaderField("ETag"), serverNow)
        } finally { abort.cancel(false); connection.disconnect() }
    }

    private fun execute(context: Context, config: JSONObject, action: String, started: Long) {
        val auth = FirebaseAuth.getInstance()
        val user = auth.currentUser
        if (user == null || user.isAnonymous || user.uid != config.getString("ownerId")) { main.post { clear(context) }; return }
        val token = Tasks.await(user.getIdToken(false), 1500, TimeUnit.MILLISECONDS).token ?: error("Login required")
        val deadline = started + 6500
        val path = "users/${Uri.encode(user.uid)}/activeSession"
        val fetched = request(path, token, deadline)
        val state = fetched.json
        if (state.optString("id") != config.getString("sessionId") || state.optString("status") == "completed") {
            main.post { if (load(context)?.optString("sessionId") == config.getString("sessionId")) clear(context) }; return
        }
        val position = ClassCommand.position(state, config, fetched.serverNow)
        if (position.index >= config.getJSONArray("steps").length()) {
            main.post { if (load(context)?.optString("sessionId") == config.getString("sessionId")) clear(context) }; return
        }
        check(auth.currentUser?.uid == user.uid && load(context)?.optString("sessionId") == config.getString("sessionId"))
        val confirmed = if (action == "refresh") fetched else {
            // A stale notification is refreshed rather than applying an ambiguous command.
            if (state.getLong("revision") != config.getLong("revision")) {
                main.post { update(context, config, fetched) }; return
            }
            val updated = ClassCommand.apply(state, config, action, fetched.serverNow)
            request(path, token, deadline, updated, fetched.etag)
        }
        main.post { update(context, config, confirmed) }
        if (action != "refresh" && confirmed.json.optString("status") == "completed") {
            // Deterministic audit id: logging retries cannot duplicate the completion event.
            val commandId = confirmed.json.getJSONObject("notificationCommand").getString("id")
            val event = JSONObject().put("id", commandId).put("type", "playback_completed")
                .put("occurredAtMs", confirmed.json.getLong("anchorServerMs"))
                .put("deviceId", config.getString("deviceId"))
                .put("workoutId", confirmed.json.optString("workoutId", confirmed.json.optJSONObject("workoutSnapshot")?.optString("id") ?: ""))
                .put("workoutName", config.getString("workoutName")).put("scheduled", false)
            try { request("users/${Uri.encode(user.uid)}/operations/events/$commandId", token, deadline, event, conditional = false) }
            catch (_: Exception) { /* Confirmed class stop must not be reported as failed if audit logging times out. */ }
        }
    }

    private fun update(context: Context, config: JSONObject, response: Response) {
        val latest = load(context) ?: return
        if (latest.optString("sessionId") != config.getString("sessionId") || latest.optLong("revision") > response.json.getLong("revision")) return
        for (key in listOf("status", "stepIndex", "remainingMs", "anchorServerMs", "revision", "startDelayMs")) config.put(key, response.json.opt(key))
        config.put("connected", true)
        config.put("serverOffsetMs", response.serverNow - System.currentTimeMillis())
        prefs(context).edit().putString("config", config.toString()).apply()
        show(context, config)
    }
}

class ClassControlReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ClassNotifications.DISMISS) {
            ClassNotifications.dismiss(context, intent.getStringExtra("sessionId"))
            return
        }
        val pending = goAsync()
        ClassNotifications.receive(context, intent) { pending.finish() }
    }
}
