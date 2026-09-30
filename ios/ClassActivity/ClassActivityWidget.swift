import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct ClassActivityBundle: WidgetBundle {
    var body: some Widget { ClassActivityWidget() }
}

struct ClassActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivityAttributes.self) { context in
            ClassActivityCard(context: context)
                .padding(16)
                .environment(\.colorScheme, .light)
                .foregroundStyle(.black)
                .activityBackgroundTint(Color(red: 0.97, green: 0.96, blue: 0.99))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("CloudBoard", systemImage: "rectangle.on.rectangle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ClassActivityTimer(state: context.state)
                        .font(.title3.bold()).frame(maxWidth: 100)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(context.attributes.workoutName).font(.headline).lineLimit(1)
                        ClassActivityStatus(context: context)
                        ClassActivityActions(context: context)
                    }.padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(Color(red: 0.49, green: 0.46, blue: 0.63))
            } compactTrailing: {
                ClassActivityTimer(state: context.state)
                    .font(.caption.monospacedDigit()).frame(width: 52)
            } minimal: {
                Image(systemName: context.isStale ? "arrow.clockwise" : (context.state.isPaused ? "pause.fill" : "timer"))
            }
            .keylineTint(Color(red: 0.49, green: 0.46, blue: 0.63))
        }
    }
}

private struct ClassActivityCard: View {
    let context: ActivityViewContext<ClassActivityAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CloudBoard · 진행 중인 수업").font(.caption).foregroundStyle(.secondary)
                    Text(context.attributes.workoutName).font(.headline).lineLimit(1)
                    ClassActivityStatus(context: context)
                }
                Spacer(minLength: 0)
                ClassActivityTimer(state: context.state)
                    .font(.title2.bold()).frame(width: 100)
            }
            ClassActivityActions(context: context)
        }
    }
}

private struct ClassActivityStatus: View {
    let context: ActivityViewContext<ClassActivityAttributes>
    var body: some View {
        Text(context.state.message ?? (context.isStale ? (context.state.isPaused ? "마지막 확인: 일시정지" : "예상 남은 시간 · 새로고침 가능") : (context.state.isPaused ? "일시정지" : "수업 종료까지")))
            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
    }
}

private struct ClassActivityTimer: View {
    let state: ClassActivityAttributes.ContentState
    var body: some View {
        Group {
            if let end = state.endsAt, end > state.confirmedAt {
                Text(timerInterval: state.confirmedAt...end, countsDown: true, showsHours: true)
                    .monospacedDigit().multilineTextAlignment(.trailing)
            } else {
                Text(String(format: "%d:%02d", state.remainingSeconds / 60, state.remainingSeconds % 60)).monospacedDigit()
            }
        }
    }
}

private struct ClassActivityActions: View {
    let context: ActivityViewContext<ClassActivityAttributes>
    private let accent = Color(red: 0.49, green: 0.46, blue: 0.63)
    var body: some View {
        if #available(iOS 17.0, *) {
            HStack(spacing: 8) {
                action("이전", icon: "backward.end.fill", command: "previousSlide")
                action(context.state.isPaused ? "재개" : "일시정지",
                       icon: context.state.isPaused ? "play.fill" : "pause.fill",
                       command: context.state.isPaused ? "resume" : "pause")
                action("다음", icon: "forward.end.fill", command: "nextSlide")
                Button(intent: ClassActivityIntent(sessionID: context.attributes.sessionID, action: "refresh")) {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                        .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).foregroundStyle(accent).accessibilityLabel("수업 상태 새로고침")
            }
        } else {
            Text("앱에서 수업을 조작하세요").font(.caption).foregroundStyle(.secondary)
        }
    }

    @available(iOS 17.0, *)
    private func action(_ title: String, icon: String, command: String) -> some View {
        Button(intent: ClassActivityIntent(sessionID: context.attributes.sessionID, action: command)) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }.font(.caption.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).foregroundStyle(accent).accessibilityLabel(title)
    }
}
