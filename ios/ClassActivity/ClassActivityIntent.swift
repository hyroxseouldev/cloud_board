import AppIntents
import Foundation

/// Runs in the app process, where Firebase authentication and the session binding live.
/// The extension renders buttons but never receives credentials.
@available(iOS 17.0, *)
struct ClassActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "진행 중인 수업 제어"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "수업") var sessionID: String
    @Parameter(title: "동작") var action: String

    init() {}
    init(sessionID: String, action: String) {
        self.sessionID = sessionID
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        #if !CLASS_ACTIVITY_EXTENSION
        do {
            #if DEBUG
            if await ClassActivityPreview.execute(action, sessionID: sessionID) {
                return .result()
            }
            #endif
            try await ClassControlsService.shared.execute(action, expectedSessionID: sessionID)
        } catch {
            let failure = error as? ClassControlCommand.Failure
            await ClassLiveActivityCoordinator.shared.showFailure(sessionID: sessionID, message: failure?.message)
            if let failure { throw failure }
            // URLSession/Firebase errors may contain a credential-bearing URL.
            throw ClassActivityIntentError()
        }
        #else
        // LiveActivityIntent must be dispatched to Runner, never the extension.
        try rejectExtensionExecution()
        #endif
        return .result()
    }

    private func rejectExtensionExecution() throws { throw ClassActivityIntentError() }
}

private struct ClassActivityIntentError: LocalizedError {
    var errorDescription: String? { "앱에서 현재 수업을 확인해 주세요." }
}
