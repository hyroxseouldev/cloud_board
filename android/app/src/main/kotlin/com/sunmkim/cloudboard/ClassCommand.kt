package com.sunmkim.cloudboard

import org.json.JSONObject
import kotlin.math.max

/** Pure session reducer shared by all notification actions. No offline writes. */
internal object ClassCommand {
    data class Position(val index: Int, val remaining: Long, val countdown: Long)

    fun position(state: JSONObject, config: JSONObject, now: Long): Position {
        val steps = config.getJSONArray("steps")
        var index = state.getInt("stepIndex").coerceIn(0, steps.length())
        if (state.getString("status") == "completed") return Position(steps.length(), 0, 0)
        var remaining = state.getLong("remainingMs")
        if (state.getString("status") != "playing") return Position(index, remaining, 0)
        val elapsed = max(0, now - state.getLong("anchorServerMs"))
        val delay = state.optLong("startDelayMs")
        remaining -= max(0, elapsed - delay)
        while (remaining <= 0 && index < steps.length()) {
            index++
            if (index < steps.length()) remaining += steps.getJSONObject(index).getLong("durationMs")
        }
        return Position(index, max(0, remaining), max(0, delay - elapsed))
    }

    fun apply(state: JSONObject, config: JSONObject, action: String, now: Long): JSONObject {
        require(state.getString("id") == config.getString("sessionId")) { "수업이 변경되었습니다" }
        require(state.getString("ownerId") == config.getString("ownerId")) { "계정이 변경되었습니다" }
        require(state.getString("status") != "completed" && !state.optBoolean("briefing")) { "종료되었거나 준비 중인 수업입니다" }
        val position = position(state, config, now)
        val steps = config.getJSONArray("steps")
        require(position.index < steps.length()) { "종료된 수업입니다" }
        require(position.countdown == 0L) { "시작 카운트다운 중입니다" }
        var index = position.index
        var remaining = position.remaining
        var status = state.getString("status")
        when (action) {
            "pause" -> { require(status == "playing"); status = "paused" }
            "play" -> { require(status == "paused"); status = "playing" }
            "next" -> { index++; status = "playing"; remaining = if (index < steps.length()) steps.getJSONObject(index).getLong("durationMs") else 0 }
            "previous" -> {
                val duration = steps.getJSONObject(index).getLong("durationMs")
                if (remaining >= duration - 3000) index = max(0, index - 1)
                remaining = steps.getJSONObject(index).getLong("durationMs")
                status = "playing"
            }
            "stop" -> { status = "completed"; remaining = 0 }
            else -> error("알 수 없는 명령입니다")
        }
        if (index == steps.length()) status = "completed"
        return JSONObject(state.toString()).apply {
            put("status", status); put("stepIndex", index); put("remainingMs", remaining)
            put("startDelayMs", 0); put("briefing", false)
            put("revision", state.getLong("revision") + 1)
            put("updatedByDeviceId", config.getString("deviceId"))
            put("anchorServerMs", JSONObject().put(".sv", "timestamp"))
            // Server rules enforce the deadline even if a socket times out locally.
            put("notificationCommand", JSONObject().put("expiresAtMs", now + 6000)
                .put("id", java.util.UUID.randomUUID().toString()))
        }
    }
}
