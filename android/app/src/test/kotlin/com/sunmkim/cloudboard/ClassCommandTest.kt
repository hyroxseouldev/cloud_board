package com.sunmkim.cloudboard

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class ClassCommandTest {
    private fun config() = JSONObject("""{"ownerId":"owner","sessionId":"a","deviceId":"phone","steps":[{"durationMs":10000},{"durationMs":20000},{"durationMs":5000}]}""")
    private fun state() = JSONObject("""{"id":"a","ownerId":"owner","status":"playing","stepIndex":0,"remainingMs":10000,"anchorServerMs":1000,"revision":4} """)
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
        assertThrows(IllegalArgumentException::class.java) { ClassCommand.apply(state().put("startDelayMs", 3000), config(), "pause", 2000) }
        assertThrows(IllegalArgumentException::class.java) { ClassCommand.apply(state().put("ownerId", "other"), config(), "stop", 1000) }
    }
    @Test fun commandHasFiniteServerDeadlineAndUniqueIdentity() {
        val first = ClassCommand.apply(state(), config(), "stop", 1000).getJSONObject("notificationCommand")
        val second = ClassCommand.apply(state(), config(), "stop", 1000).getJSONObject("notificationCommand")
        assertEquals(7000, first.getLong("expiresAtMs"))
        assertNotEquals(first.getString("id"), second.getString("id"))
    }
}
