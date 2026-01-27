import SwiftUI
import ComposableArchitecture
import SharedDomain

// MARK: - WatchAlarmView
struct WatchAlarmView: View {
    let store: StoreOf<WatchAlarmFeature>

    var body: some View {
        ZStack {
            // 배경 색상 (상태에 따라)
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 12) {
                switch store.alarmState {
                case .ringing:
                    ringingContent

                case .snoozed:
                    snoozedContent

                case .dismissed:
                    dismissedContent

                case .idle:
                    EmptyView()
                }
            }
            .padding()
        }
    }

    // MARK: - Ringing State
    @ViewBuilder
    private var ringingContent: some View {
        // 알람 아이콘 + 애니메이션
        Image(systemName: "alarm.fill")
            .font(.system(size: 44))
            .foregroundColor(.white)
            .symbolEffect(.pulse.wholeSymbol, options: .repeating)

        // 발화 이유
        if let event = store.triggerEvent {
            Text(event.reason == .smart ? "Smart Wake" : "Wake Time")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))

            Text("\(Int(event.score * 100))% Score")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }

        Spacer()

        // 버튼 영역
        HStack(spacing: 16) {
            // Snooze 버튼
            Button {
                store.send(.snoozeTapped)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                    Text("5min")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.8))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Stop 버튼
            Button {
                store.send(.stopTapped)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text("Stop")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.9))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Snoozed State
    @ViewBuilder
    private var snoozedContent: some View {
        Image(systemName: "moon.zzz.fill")
            .font(.system(size: 36))
            .foregroundColor(.orange)

        Text("Snoozed")
            .font(.headline)
            .foregroundColor(.primary)

        // 남은 시간 표시
        Text(store.snoozeRemainingText)
            .font(.system(size: 32, weight: .bold, design: .monospaced))
            .foregroundColor(.orange)

        if store.snoozeCount > 1 {
            Text("Snooze #\(store.snoozeCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }

        Spacer()

        // Stop 버튼 (스누즈 중에도 완전 종료 가능)
        Button {
            store.send(.stopTapped)
        } label: {
            HStack {
                Image(systemName: "stop.fill")
                Text("Stop Alarm")
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.8))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dismissed State
    @ViewBuilder
    private var dismissedContent: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 44))
            .foregroundColor(.green)

        Text("Good Morning!")
            .font(.headline)

        if let event = store.triggerEvent {
            Text("Woke at \(formattedTime(event.timestamp))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers
    private var backgroundColor: Color {
        switch store.alarmState {
        case .ringing:
            return Color.red.opacity(0.85)
        case .snoozed:
            return Color.black
        case .dismissed:
            return Color.black
        case .idle:
            return Color.black
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview("Ringing") {
    WatchAlarmView(
        store: Store(
            initialState: WatchAlarmFeature.State(
                alarmState: .ringing,
                triggerEvent: TriggerEvent(
                    reason: .smart,
                    timestamp: Date(),
                    score: 0.78,
                    components: WakeabilityScore.Components(motionScore: 0.82, heartRateScore: 0.71)
                )
            )
        ) {
            WatchAlarmFeature()
        }
    )
}

#Preview("Snoozed") {
    WatchAlarmView(
        store: Store(
            initialState: WatchAlarmFeature.State(
                alarmState: .snoozed(resumeAt: Date().addingTimeInterval(180)),
                snoozeCount: 1,
                now: Date()
            )
        ) {
            WatchAlarmFeature()
        }
    )
}

#Preview("Dismissed") {
    WatchAlarmView(
        store: Store(
            initialState: WatchAlarmFeature.State(
                alarmState: .dismissed,
                triggerEvent: TriggerEvent(
                    reason: .smart,
                    timestamp: Date(),
                    score: 0.75,
                    components: WakeabilityScore.Components(motionScore: 0.8, heartRateScore: 0.65)
                )
            )
        ) {
            WatchAlarmFeature()
        }
    )
}
