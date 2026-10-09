package com.sunmkim.cloudboard

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class ClassCommandTest {
    @Test fun forTimeOpenClockCapAndCompletedCommands() {
        val c = config().put("steps", org.json.JSONArray("""[{"durationMs":0,"forTime":true},{"durationMs":10000}]"""))
        val open = state().put("remainingMs", 0).put("startDelayMs", 3000)
        assertEquals(0L, ClassCommand.position(open, c, 2000).remaining)
        assertEquals(1500L, ClassCommand.position(open, c, 5500).remaining)
        val paused = ClassCommand.apply(open, c, "pause", 5500)
        assertEquals(1500L, ClassCommand.position(paused, c, 99000).remaining)
        val finished = paused.put("timerCompleted", true)
        assertThrows(IllegalArgumentException::class.java) { ClassCommand.apply(finished, c, "play", 99000) }
        val next = ClassCommand.apply(finished, c, "next", 99000)
        assertEquals(1, next.getInt("stepIndex"))
        assertEquals("playing", next.getString("status"))
        assertFalse(next.getBoolean("timerCompleted"))
        c.getJSONArray("steps").getJSONObject(0).put("durationMs", 10000)
        val atCap = ClassCommand.position(state(), c, 99999)
        assertEquals(0, atCap.index)
        assertEquals(0L, atCap.remaining)
        val atCapNext = ClassCommand.apply(state(), c, "next", 99999)
        assertEquals(1, atCapNext.getInt("stepIndex"))
    }
    private fun config() = JSONObject("""{"ownerId":"owner","sessionId":"a","deviceId":"phone","steps":[{"durationMs":10000},{"durationMs":20000},{"durationMs":5000}]}""")
    private fun state() = JSONObject("""{"id":"a","ownerId":"owner","status":"playing","stepIndex":0,"remainingMs":10000,"anchorServerMs":1000,"revision":4} """)
    @Test fun splitSessionCommandsPreserveSnapshotReferenceWithoutLoadingContent() {
        val split = state().put("schemaVersion", 2).put("snapshotId", "a").put("workoutId", "w")
        val stopped = ClassCommand.apply(split, config(), "stop", 1000)
        assertFalse(stopped.has("workoutSnapshot"))
        assertEquals("a", stopped.getString("snapshotId"))
        assertEquals("w", stopped.getString("workoutId"))
        assertEquals("completed", stopped.getString("status"))
    }
    @Test fun pauseResolvesElapsedStepsAndPreservesRemaining() {
        val result = ClassCommand.apply(state(), config(), "pause", 12000)
        assertEquals("paused", result.getString("status"))
        assertEquals(1, result.getInt("stepIndex"))
        assertEquals(19000, result.getLong("remainingMs"))
        assertEquals(5, result.getInt("revision"))
    }
    @Test fun resumeDoesNotSubtractPausedTime() {
        val paused = state().put("status", "paused").put("remainingMs", 4500)
        assertEquals(4500, ClassCommand.apply(paused, config(), "play", 50000).getLong("remainingMs"))
    }
    @Test fun previousRestartsAfterThreeSeconds() {
        val active = state().put("stepIndex", 1).put("remainingMs", 20000)
        assertEquals(1, ClassCommand.apply(active, config(), "previous", 5000).getInt("stepIndex"))
        assertEquals(0, ClassCommand.apply(active, config(), "previous", 2000).getInt("stepIndex"))
    }
    @Test fun pausedNavigationNeverResumes() {
        val paused = state().put("status", "paused").put("stepIndex", 1).put("remainingMs", 20000)
        for (action in listOf("next", "previous")) {
            val result = ClassCommand.apply(paused, config(), action, 50000)
            assertEquals("paused", result.getString("status"))
            assertEquals(if (action == "next") 2 else 0, result.getInt("stepIndex"))
        }
    }
    @Test fun nextAtLastStepCompletes() {
        val active = state().put("stepIndex", 2).put("remainingMs", 5000)
        assertEquals("completed", ClassCommand.apply(active, config(), "next", 1000).getString("status"))
    }
    @Test fun completedReplacedAndExpiredSessionsRejectCommands() {
        for (value in listOf(state().put("status", "completed"), state().put("id", "b"), state())) {
            assertThrows(IllegalArgumentException::class.java) { ClassCommand.apply(value, config(), "next", 99999) }
        }
    }
    @Test fun countdownAndWrongAccountRejectCommands() {
        assertThrows(IllegalArgumentException::class.java) { ClassCommand.apply(state().put("startDelayMs", 3000), config(), "next", 2000) }
        assertThrows(IllegalArgumentException::class.java) { ClassCommand.apply(state().put("ownerId", "other"), config(), "stop", 1000) }
    }
    @Test fun pausedCountdownFreezesAndResumesRemainingDelay() {
        val paused = ClassCommand.apply(state().put("startDelayMs", 3000), config(), "pause", 2000)
        assertEquals(2000L, paused.getLong("startDelayMs"))
        assertEquals(2000L, ClassCommand.position(paused, config(), 50000).countdown)
        val resumed = ClassCommand.apply(paused, config(), "play", 50000)
        assertEquals(2000L, resumed.getLong("startDelayMs"))
        assertEquals(10000L, resumed.getLong("remainingMs"))
    }
    @Test fun commandHasFiniteServerDeadlineAndUniqueIdentity() {
        val first = ClassCommand.apply(state(), config(), "stop", 1000).getJSONObject("notificationCommand")
        val second = ClassCommand.apply(state(), config(), "stop", 1000).getJSONObject("notificationCommand")
        assertEquals(7000, first.getLong("expiresAtMs"))
        assertNotEquals(first.getString("id"), second.getString("id"))
    }
}
