#if DEBUG
import ActivityKit
import Foundation

/// Opt-in simulator fixture. Never reads/writes a Firebase session or account binding.
@MainActor
enum ClassActivityPreview {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--class-activity-preview") }
    private static var config: [String: Any]?
    static func startIfNeeded() {
        guard isEnabled, config == nil else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        config = [
            "sessionId": "class-activity-preview", "ownerId": "preview", "deviceId": "preview",
            "workoutName": "오후 서킷 트레이닝", "status": "playing", "stepIndex": 0,
            "remainingMs": 300000, "startDelayMs": 0, "anchorServerMs": now,
            "serverOffsetMs": 0, "revision": 1,
            "steps": [["durationMs": 300000, "moduleIndex": 0], ["durationMs": 300000, "moduleIndex": 1]]
        ]
        let initial = ClassLiveActivityCoordinator.shared.project(config)
        if ProcessInfo.processInfo.arguments.contains("--class-activity-self-test") {
            Task { @MainActor in
                await initial.value
                guard #available(iOS 17.0, *) else { return }
                do {
                    for action in ["pause", "nextSlide", "resume", "previousSlide", "refresh", "pause"] {
                        _ = try await ClassActivityIntent(sessionID: "class-activity-preview", action: action).perform()
                        await ClassLiveActivityCoordinator.shared.project(config).value
                        let expectedPaused = config?["status"] as? String == "paused"
                        // ActivityKit content delivery is asynchronous even after update returns.
                        await expectEventually {
                            Activity<ClassActivityAttributes>.activities.first?.content.state.isPaused == expectedPaused
                        }
                    }
                    precondition(config?["stepIndex"] as? Int == 0)
                    var completed = config!
                    completed["status"] = "completed"
                    await ClassLiveActivityCoordinator.shared.project(completed).value
                    await expectEventually { Activity<ClassActivityAttributes>.activities.isEmpty }
                    await ClassLiveActivityCoordinator.shared.project(config).value
                    NSLog("PASS: Live Activity AppIntent pause, next, resume, previous, refresh and completion")
                } catch { preconditionFailure("Live Activity preview intent failed: \(error)") }
            }
        }
    }

    private static func expectEventually(_ condition: () -> Bool) async {
        for _ in 0..<30 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        precondition(condition(), "Live Activity did not deliver its projected state")
    }

    static func execute(_ action: String, sessionID: String) -> Bool {
        guard isEnabled, sessionID == "class-activity-preview", var value = config else { return false }
        if action != "refresh" {
            var state = value
            state["id"] = sessionID
            guard var updated = try? ClassControlCommand.apply(state, config: value, action: action,
                now: Int64(Date().timeIntervalSince1970 * 1000)) else { return true }
            updated["anchorServerMs"] = Int64(Date().timeIntervalSince1970 * 1000)
            for (key, item) in updated { value[key] = item }
            config = value
        }
        ClassLiveActivityCoordinator.shared.project(value)
        NSLog("Class Activity preview command: %@", action)
        return true
    }
}
#endif
