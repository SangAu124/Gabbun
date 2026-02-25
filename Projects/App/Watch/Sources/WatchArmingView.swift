import SwiftUI
import ComposableArchitecture

// MARK: - WatchArmingView
public struct WatchArmingView: View {
    let store: StoreOf<WatchArmingFeature>

    public init(store: StoreOf<WatchArmingFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 상태 헤더
                statusHeader

                Divider()

                // 스케줄 정보
                if store.schedule != nil {
                    scheduleInfo
                } else {
                    noScheduleView
                }
            }
            .padding()
        }
    }

    // MARK: - Status Header
    private var statusHeader: some View {
        VStack(spacing: 4) {
            Text(store.armingState.rawValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(statusColor)

            statusIcon
                .frame(width: 20, height: 20)
        }
    }

    private var statusColor: Color {
        switch store.armingState {
        case .idle:
            return .secondary
        case .armed:
            return .green
        case .monitoring:
            return .blue
        case .triggered:
            return .orange
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch store.armingState {
        case .idle:
            Circle()
                .fill(Color.gray.opacity(0.5))
        case .armed:
            Circle()
                .fill(Color.green)
        case .monitoring:
            Image(systemName: "waveform.path.ecg")
                .foregroundColor(.blue)
                .symbolEffect(.pulse)
        case .triggered:
            Image(systemName: "alarm.fill")
                .foregroundColor(.orange)
                .symbolEffect(.bounce)
        }
    }

    // MARK: - Schedule Info
    private var scheduleInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Enabled
            HStack {
                Text("Enabled")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(store.enabled ? "ON" : "OFF")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(store.enabled ? .green : .red)
            }

            // Target Wake Time
            HStack {
                Text("Wake Time")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if let targetWakeTime = store.targetWakeTime {
                    Text(formatTime(targetWakeTime))
                        .font(.caption)
                        .fontWeight(.medium)
                } else {
                    Text("--:--")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Window Start Time
            HStack {
                Text("Window Start")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if let windowStartTime = store.windowStartTime {
                    Text(formatTime(windowStartTime))
                        .font(.caption)
                        .fontWeight(.medium)
                } else {
                    Text("--:--")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Window Duration
            if let schedule = store.schedule {
                HStack {
                    Text("Window")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(schedule.windowMinutes) min")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Sensitivity
            if let schedule = store.schedule {
                HStack {
                    Text("Sensitivity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(schedule.sensitivity.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - No Schedule View
    private var noScheduleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No Schedule")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Set alarm from iPhone")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Helpers
    private func formatTime(_ date: Date) -> String {
        // Calendar.current로 DateComponents 추출 — 항상 현재 timezone 반영, thread-safe
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return String(format: "%02d:%02d", h, m)
    }
}
