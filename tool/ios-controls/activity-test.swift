import Foundation

@main struct ActivityChecks {
    static func main() {
        let now = Date(timeIntervalSince1970: 100)
        var config: [String: Any] = [
            "sessionId": "s", "workoutName": "Circuit", "status": "playing",
            "stepIndex": 0, "remainingMs": 10000, "anchorServerMs": 70000,
            "steps": [["durationMs": 10000], ["durationMs": 5000], ["durationMs": 10000], ["durationMs": 20000]]
        ]
        let later = ClassActivityProjection(config, now: now)!
        precondition(later.remainingSeconds == 15, "Elapsed interval boundaries must not restart the class")
        precondition(later.endsAt == now.addingTimeInterval(15))
        config["status"] = "paused"
        let paused = ClassActivityProjection(config, now: now)!
        precondition(paused.remainingSeconds == 45 && paused.endsAt == nil)
        config["status"] = "playing"
        config["serverOffsetMs"] = 2000
        precondition(ClassActivityProjection(config, now: now)!.remainingSeconds == 13)
        config["startDelayMs"] = 5000
        precondition(ClassActivityProjection(config, now: now)!.remainingSeconds == 18)
        config["briefing"] = true
        precondition(ClassActivityProjection(config, now: now) == nil)
        config["briefing"] = false
        precondition(ClassActivityProjection(config, now: now.addingTimeInterval(60)) == nil)
        config["stepIndex"] = -1
        precondition(ClassActivityProjection(config, now: now) == nil)
        config["stepIndex"] = 0
        config["status"] = "completed"
        precondition(ClassActivityProjection(config, now: now) == nil)
        config["status"] = "playing"
        config["steps"] = [["durationMs":10000, "forTime":true]]
        precondition(ClassActivityProjection(config, now: now) == nil, "For Time has no projected class end")
        print("PASS: activity elapsed time, paused timer, server offset, countdown, briefing, completion and invalid position")
    }
}
