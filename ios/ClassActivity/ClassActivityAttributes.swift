import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct ClassActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var remainingSeconds: Int
        var endsAt: Date?
        var confirmedAt: Date
        var message: String?
    }

    let sessionID: String
    let workoutName: String
}
