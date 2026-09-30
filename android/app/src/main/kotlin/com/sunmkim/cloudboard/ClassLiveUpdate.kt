package com.sunmkim.cloudboard

import androidx.core.app.NotificationCompat
import java.util.Locale

/** Standard notification content is required for Android Live Updates (no RemoteViews).
 * The OS owns the countdown, so no per-second worker/service is required. Promotion
 * remains subject to user settings and OEM support; the same card also works normally.
 */
internal object ClassLiveUpdate {
    fun apply(builder: NotificationCompat.Builder, remainingMs: Long, paused: Boolean,
              confirmed: Boolean, now: Long = System.currentTimeMillis()) {
        builder.setOngoing(confirmed)
            .setRequestPromotedOngoing(confirmed)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setShortCriticalText(if (!confirmed) "확인 필요" else if (paused) "일시정지" else null)
            .setUsesChronometer(confirmed && !paused)
            .setChronometerCountDown(true)
            .setShowWhen(confirmed && !paused)
            .setWhen(if (confirmed && !paused) now + remainingMs.coerceAtLeast(0) else 0)
    }

    fun remainingText(remainingMs: Long): String {
        val seconds = (remainingMs.coerceAtLeast(0) + 999) / 1000
        return String.format(Locale.ROOT, "%d:%02d", seconds / 60, seconds % 60)
    }
}
