import Foundation

@main struct Checks {
  static func main() throws {
    let config: [String: Any] = ["ownerId":"u", "sessionId":"s", "deviceId":"c", "steps":[
        ["durationMs":10000,"moduleIndex":0], ["durationMs":5000,"moduleIndex":0],
        ["durationMs":10000,"moduleIndex":0], ["durationMs":20000,"moduleIndex":1]]]
    let state: [String: Any] = ["id":"s","ownerId":"u","status":"playing","stepIndex":0,"remainingMs":10000,"anchorServerMs":1000,"revision":1]
    let paused = try ClassControlCommand.apply(state, config:config, action:"pause", now:31000)
    precondition(paused["stepIndex"] as? Int == 3)
    precondition(paused["remainingMs"] as? Int64 == 15000)
    var frozen = state; frozen["status"] = "paused"
    let next = try ClassControlCommand.apply(frozen, config:config, action:"nextSlide", now:900000)
    precondition(next["stepIndex"] as? Int == 3)
    precondition(next["status"] as? String == "paused")
    let previous = try ClassControlCommand.apply(next, config:config, action:"previousSlide", now:900000)
    precondition(previous["stepIndex"] as? Int == 0)
    precondition(previous["status"] as? String == "paused")
    var failures = 0
    for variant in [state.merging(["id":"new"]) { _,new in new }, state.merging(["status":"completed"]) { _,new in new }, state.merging(["ownerId":"other"]) { _,new in new }] {
      do { _ = try ClassControlCommand.apply(variant, config:config, action:"pause", now:2000) }
      catch { failures += 1 }
    }
    precondition(failures == 3)
    let resumed = try ClassControlCommand.apply(frozen, config:config, action:"resume", now:900000)
    precondition(resumed["remainingMs"] as? Int64 == 10000)
    precondition(resumed["status"] as? String == "playing")
    var split = state
    split["schemaVersion"] = 2; split["snapshotId"] = "s"
    split["workoutId"] = "w"; split["workoutName"] = "Frozen class"
    let splitPaused = try ClassControlCommand.apply(split, config:config, action:"pause", now:2000)
    precondition(splitPaused["snapshotId"] as? String == "s")
    precondition(splitPaused["workoutSnapshot"] == nil)
    precondition(splitPaused["status"] as? String == "paused")
    print("PASS: iOS elapsed position, paused slide navigation, resume, replaced/ended/wrong-owner rejection")
  }
}
