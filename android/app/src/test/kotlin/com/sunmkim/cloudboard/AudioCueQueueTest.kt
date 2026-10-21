package com.sunmkim.cloudboard

import org.junit.Assert.*
import org.junit.Test

class AudioCueQueueTest {
    private class Rig {
        var wall = 10000L
        var uptime = 1000L
        var elapsed = 2000L
        val scheduled = linkedMapOf<Runnable, Long>()
        val played = mutableListOf<String>()
        val dropped = mutableListOf<String>()
        var stops = 0
        val queue = AudioCueQueue({wall}, {uptime}, {elapsed},
            { r, at -> scheduled[r] = at }, { scheduled.remove(it); Unit },
            { cue, _, _ -> played.add(cue.id) }, { stops++ }, { cue, _ -> dropped.add(cue.id) })
        fun advance(ms: Long) { wall += ms; uptime += ms; elapsed += ms }
        fun run() { scheduled.filterValues { it <= uptime }.keys.toList().forEach { scheduled.remove(it); it.run() } }
        fun cue(id: String = "cue", deadline: Long = 11000) = AudioCueQueue.Cue(id, "videoBeep:start", deadline)
    }
    @Test fun absoluteDeadlineIndependentOfPollingPhaseAndWallJump() {
        val a = Rig(); val b = Rig(); b.advance(89)
        a.queue.activate("a"); b.queue.activate("b")
        a.queue.replace("a", listOf(a.cue()), 1f); b.queue.replace("b", listOf(b.cue()), 1f)
        assertEquals(2000L, a.scheduled.values.maxOrNull()); assertEquals(2000L, b.scheduled.values.maxOrNull())
        a.wall += 50000 // Already admitted cues follow monotonic, not adjusted wall clock.
        a.advance(1000); a.run(); assertEquals(listOf("cue"), a.played)
    }
    @Test fun repeatedWindowAndNewOwnerCannotReplayConsumedCue() {
        val r = Rig(); r.queue.activate("a")
        repeat(4) { r.queue.replace("a", listOf(r.cue()), 1f) }
        assertEquals(2, r.scheduled.size)
        r.advance(1000); r.run()
        r.queue.activate("b")
        r.queue.replace("b", listOf(r.cue(deadline = 12000)), 1f)
        assertTrue(r.scheduled.isEmpty()); assertEquals(listOf("cue"), r.played)
    }
    @Test fun cancellationStaleOwnerAndVolumeOffRemoveNativeCallbacks() {
        val r = Rig(); r.queue.activate("a"); r.queue.replace("a", listOf(r.cue()), 1f)
        r.queue.cancel("a"); assertTrue(r.scheduled.isEmpty())
        r.queue.activate("b"); r.queue.replace("a", listOf(r.cue()), 1f)
        assertTrue(r.scheduled.isEmpty())
        r.queue.replace("b", listOf(r.cue()), 1f); r.queue.cancel("a")
        assertEquals(2, r.scheduled.size)
        r.queue.replace("b", listOf(r.cue()), 0f); assertTrue(r.scheduled.isEmpty())
    }
    @Test fun suspendLateAndDeepSleepNeverBurst() {
        val r = Rig(); r.queue.activate("a"); r.queue.replace("a", listOf(r.cue()), 1f)
        r.advance(1200); r.run(); assertTrue(r.played.isEmpty()); assertEquals(listOf("cue"), r.dropped)
        r.queue.replace("a", listOf(r.cue("next", 12000)), 1f)
        r.elapsed += 10000 // Sleep advances elapsedRealtime, not Handler uptime.
        r.advance(800); r.run(); assertEquals(listOf("cue", "next"), r.dropped)
        r.queue.replace("a", listOf(r.cue("suspend", 13000)), 1f)
        r.queue.suspend(); assertTrue(r.scheduled.isEmpty())
    }
    @Test fun revisionReplacesOldPlanAndPastOrDistantCuesNeverSchedule() {
        val r = Rig(); r.queue.activate("old"); r.queue.replace("old", listOf(r.cue()), 1f)
        r.queue.activate("new")
        r.queue.replace("new", listOf(r.cue("past", 9999), r.cue("far", 18000), r.cue("fresh", 11000)), 1f)
        assertEquals(2, r.scheduled.size); r.advance(1000); r.run(); assertEquals(listOf("fresh"), r.played)
    }
    @Test fun naturalCompletionCanCancelFutureWorkWithoutCuttingStartedTail() {
        val r = Rig(); r.queue.activate("a")
        r.queue.replace("a", listOf(r.cue()), 1f); r.advance(1000); r.run()
        val stops = r.stops
        r.queue.cancel("a", stopPlaying = false)
        assertEquals(stops, r.stops); assertTrue(r.scheduled.isEmpty())
        r.queue.activate("b")
        assertTrue(r.stops > stops)
    }
    @Test fun explicitCommandIsBoundedAndSharesDedup() {
        val r = Rig(); r.queue.activate("a")
        r.queue.immediate("a", r.cue(deadline = 9900), 1f)
        r.queue.immediate("a", r.cue(deadline = 9900), 1f)
        r.queue.immediate("a", r.cue("stale", 9400), 1f)
        r.queue.immediate("old", r.cue("other", 9900), 1f)
        assertEquals(listOf("cue"), r.played)
    }
}
