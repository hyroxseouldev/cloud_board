package com.sunmkim.cloudboard

/** Pure scheduling policy; deadlines are wall→uptime converted once, never UI-tick relative. */
internal class AudioCueQueue(
    private val wallMs: () -> Long,
    private val uptimeMs: () -> Long,
    private val elapsedMs: () -> Long,
    private val postAt: (Runnable, Long) -> Unit,
    private val remove: (Runnable) -> Unit,
    private val play: (Cue, Long, Long) -> Unit,
    private val stop: () -> Unit,
    private val dropped: (Cue, Long) -> Unit = { _, _ -> },
    private val before: (Cue, Long) -> Unit = { _, _ -> },
) {
    data class Cue(val id: String, val key: String, val localDeadlineMs: Long)
    private data class Pending(val cue: Cue, val task: Runnable, val warmup: Runnable)
    private val pending = mutableMapOf<String, Pending>()
    private val consumed = linkedSetOf<String>()
    private var owner: String? = null
    var volume: Float = 1f
        private set

    fun activate(nextOwner: String, stopPlaying: Boolean = true) {
        clear(stopPlaying)
        owner = nextOwner
    }

    fun cancel(expectedOwner: String, stopPlaying: Boolean = true) {
        if (owner != expectedOwner) return
        clear(stopPlaying)
        owner = null
    }

    // Focus/background loss discards queued work but preserves the lease. Only a
    // later foreground refresh may supply *future* cues; nothing replays on gain.
    fun suspend() = clear()

    private fun clear(stopPlaying: Boolean = true) {
        pending.values.forEach { remove(it.task); remove(it.warmup) }
        pending.clear()
        if (stopPlaying) stop()
    }

    fun immediate(expectedOwner: String, cue: Cue, nextVolume: Float) {
        if (owner != expectedOwner || cue.id in consumed || cue.id in pending) return
        val age = wallMs() - cue.localDeadlineMs
        if (age !in 0..500 || nextVolume <= 0) return
        volume = nextVolume.coerceIn(0f, 1f)
        remember(cue.id)
        before(cue, uptimeMs())
        play(cue, uptimeMs(), 0)
    }

    private fun remember(id: String) {
        consumed.add(id)
        while (consumed.size > 256) consumed.remove(consumed.first())
    }

    fun replace(expectedOwner: String, cues: List<Cue>, nextVolume: Float) {
        if (owner != expectedOwner) return
        volume = nextVolume.coerceIn(0f, 1f)
        if (volume <= 0) { clear(); return }
        val nowWall = wallMs()
        val nowUptime = uptimeMs()
        val nowElapsed = elapsedMs()
        val upcoming = cues.take(32).filter {
            it.localDeadlineMs > nowWall && it.localDeadlineMs - nowWall <= 6000 &&
                it.id !in consumed
        }.associateBy { it.id }
        pending.keys.toList().forEach { id ->
            if (upcoming[id] != pending[id]?.cue) {
                pending.remove(id)?.let { remove(it.task); remove(it.warmup) }
            }
        }
        upcoming.forEach { (id, cue) ->
            if (id in pending) return@forEach
            val delay = cue.localDeadlineMs - nowWall
            val due = nowUptime + delay
            val elapsedDue = nowElapsed + delay
            val warmup = Runnable { if (owner == expectedOwner && id in pending) before(cue, due) }
            val task = Runnable {
                if (owner != expectedOwner || pending[id]?.cue != cue) return@Runnable
                pending.remove(id)
                remember(id)
                // elapsed detects deep sleep, while wall-clock corrections do not
                // shift already admitted cues. Never burst late cues on wake/jank.
                val late = maxOf(uptimeMs() - due, elapsedMs() - elapsedDue)
                if (late > 80) dropped(cue, late) else play(cue, due, late)
            }
            pending[id] = Pending(cue, task, warmup)
            postAt(warmup, maxOf(nowUptime, due - 150))
            postAt(task, due)
        }
    }
}
