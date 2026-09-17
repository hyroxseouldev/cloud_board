import Foundation

/// Pure reducer shared by Shortcuts/App Intents, independent of Flutter screens.
enum ClassControlCommand {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static func apply(_ state: [String: Any], config: [String: Any], action: String, now: Int64) throws -> [String: Any] {
        func number(_ key: String) -> Int64 { (state[key] as? NSNumber)?.int64Value ?? 0 }
        guard state["id"] as? String == config["sessionId"] as? String,
              state["ownerId"] as? String == config["ownerId"] as? String,
              let status = state["status"] as? String, ["playing", "paused"].contains(status),
              state["briefing"] as? Bool != true,
              let steps = config["steps"] as? [[String: Any]], !steps.isEmpty else {
            throw Failure(message: "수업이 종료되었거나 변경됐습니다. 앱에서 확인해 주세요.")
        }
        func duration(_ i: Int) -> Int64 { (steps[i]["durationMs"] as? NSNumber)?.int64Value ?? 0 }
        func module(_ i: Int) -> Int { (steps[i]["moduleIndex"] as? NSNumber)?.intValue ?? -1 }
        var index = Int(number("stepIndex"))
        var remaining = number("remainingMs")
        var nextStatus = status
        guard index >= 0 && index < steps.count else { throw Failure(message: "종료된 수업입니다.") }
        if status == "playing" {
            let elapsed = max(0, now - number("anchorServerMs"))
            guard elapsed >= number("startDelayMs") else { throw Failure(message: "시작 카운트다운 중입니다.") }
            remaining -= elapsed - number("startDelayMs")
            while remaining <= 0 && index < steps.count {
                index += 1
                if index < steps.count { remaining += duration(index) }
            }
        }
        guard index < steps.count else { throw Failure(message: "종료된 수업입니다.") }
        switch action {
        case "pause":
            guard status == "playing" else { throw Failure(message: "이미 일시정지 상태입니다.") }
            nextStatus = "paused"
        case "resume":
            guard status == "paused" else { throw Failure(message: "이미 재생 중입니다.") }
            nextStatus = "playing"
        case "nextSlide", "previousSlide":
            let target = module(index) + (action == "nextSlide" ? 1 : -1)
            guard let targetIndex = steps.indices.first(where: { module($0) == target }) else {
                throw Failure(message: action == "nextSlide" ? "마지막 슬라이드입니다." : "첫 슬라이드입니다.")
            }
            index = targetIndex; remaining = duration(index)
        default: throw Failure(message: "지원하지 않는 명령입니다.")
        }
        var updated = state
        updated["status"] = nextStatus
        updated["stepIndex"] = index; updated["remainingMs"] = remaining
        updated["startDelayMs"] = 0; updated["briefing"] = false
        updated["revision"] = number("revision") + 1
        updated["updatedByDeviceId"] = config["deviceId"]
        updated["anchorServerMs"] = [".sv": "timestamp"]
        updated["notificationCommand"] = ["id": UUID().uuidString, "expiresAtMs": now + 6000]
        return updated
    }
}
