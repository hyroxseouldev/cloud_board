import Foundation

/// Pure projection of the server anchor. Counts down the entire remaining class,
/// so interval transitions don't require keeping Flutter alive in the background.
struct ClassActivityProjection: Equatable {
    let sessionID: String
    let workoutName: String
    let isPaused: Bool
    let remainingSeconds: Int
    let endsAt: Date?

    init?(_ config: [String: Any], now: Date = Date()) {
        guard let id = config["sessionId"] as? String, !id.isEmpty,
              let status = config["status"] as? String,
              ["playing", "paused"].contains(status),
              config["briefing"] as? Bool != true,
              let steps = config["steps"] as? [[String: Any]], !steps.isEmpty else { return nil }
        func number(_ key: String) -> Int64 { (config[key] as? NSNumber)?.int64Value ?? 0 }
        let index = Int(number("stepIndex"))
        guard steps.indices.contains(index), number("remainingMs") >= 0 else { return nil }
        let durations = steps.map { ($0["durationMs"] as? NSNumber)?.int64Value ?? 0 }
        // For Time ends on a coach action. There is no projected class end date.
        guard !steps.contains(where: { $0["forTime"] as? Bool == true }) else { return nil }
        guard durations.allSatisfy({ $0 > 0 && $0 <= 86_400_000 }) else { return nil }
        let total = number("remainingMs") + durations.dropFirst(index + 1).reduce(0, +)
        let paused = status == "paused"
        let elapsed = paused ? 0 : max(0, Int64(now.timeIntervalSince1970 * 1000) + number("serverOffsetMs") - number("anchorServerMs"))
        let remaining = total + max(0, number("startDelayMs")) - elapsed
        guard remaining > 0 else { return nil }
        sessionID = id
        let name = (config["workoutName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        workoutName = name.isEmpty ? "진행 중인 수업" : String(name.prefix(100))
        isPaused = paused
        remainingSeconds = Int((remaining + 999) / 1000)
        endsAt = paused ? nil : now.addingTimeInterval(Double(remaining) / 1000)
    }
}
