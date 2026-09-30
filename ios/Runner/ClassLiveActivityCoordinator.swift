import ActivityKit
import Foundation
import UIKit

@MainActor
final class ClassLiveActivityCoordinator {
    static let shared = ClassLiveActivityCoordinator()
    private var pending: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?
    private var expiryTask: Task<Void, Never>?

    private init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                #if DEBUG
                if ClassActivityPreview.isEnabled {
                    ClassActivityPreview.startIfNeeded()
                    return
                }
                #endif
                if let data = UserDefaults.standard.data(forKey: ClassControlsPlugin.bindingKey),
                   let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    guard #available(iOS 16.2, *) else { return }
                    do {
                        try await ClassControlsService.shared.execute("refresh", expectedSessionID: value["sessionId"] as? String)
                    } catch {
                        await Self.shared.showFailure(sessionID: value["sessionId"] as? String ?? "")
                    }
                }
            }
        }
    }

    @discardableResult
    func project(_ config: [String: Any]?) -> Task<Void, Never> {
        let previous = pending
        let task = Task { @MainActor in
            await previous?.value
            guard #available(iOS 16.2, *) else { return }
            await apply(config)
        }
        pending = task
        return task
    }

    @available(iOS 16.2, *)
    private func apply(_ config: [String: Any]?) async {
        expiryTask?.cancel()
        let now = Date()
        guard let config, let value = ClassActivityProjection(config, now: now) else {
            for activity in Activity<ClassActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        for activity in Activity<ClassActivityAttributes>.activities where activity.attributes.sessionID != value.sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let state = ClassActivityAttributes.ContentState(
            isPaused: value.isPaused, remainingSeconds: value.remainingSeconds,
            endsAt: value.endsAt, confirmedAt: now,
            message: config["connected"] as? Bool == false ? "연결 확인 필요" : nil
        )
        // No background socket/refresh promise: stale content says it needs confirmation.
        let stale = config["connected"] as? Bool == false ? now : min(now.addingTimeInterval(60), value.endsAt ?? .distantFuture)
        let content = ActivityContent(state: state, staleDate: stale)
        if let activity = Activity<ClassActivityAttributes>.activities.first(where: { $0.attributes.sessionID == value.sessionID }) {
            await activity.update(content)
        } else if ActivityAuthorizationInfo().areActivitiesEnabled,
                  UIApplication.shared.applicationState == .active {
            do {
                _ = try Activity.request(
                    attributes: ClassActivityAttributes(sessionID: value.sessionID, workoutName: value.workoutName),
                    content: content, pushType: nil
                )
            } catch {
                NSLog("Class Live Activity could not start: %@", String(describing: error))
            }
        }
        if let end = value.endsAt {
            expiryTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(max(0, end.timeIntervalSinceNow) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.project(config)
            }
        }
    }

    func showFailure(sessionID: String, message: String? = nil) async {
        await pending?.value
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<ClassActivityAttributes>.activities where activity.attributes.sessionID == sessionID {
            var state = activity.content.state
            state.message = message ?? "반영 여부를 확인하지 못했어요. 새로고침해 주세요."
            await activity.update(ActivityContent(state: state, staleDate: Date()))
        }
    }
}
