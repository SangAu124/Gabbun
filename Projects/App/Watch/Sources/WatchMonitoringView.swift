import SwiftUI
import ComposableArchitecture
import SharedDomain

// MARK: - WatchMonitoringView
public struct WatchMonitoringView: View {
    let store: StoreOf<WatchMonitoringFeature>

    public init(store: StoreOf<WatchMonitoringFeature>) {
        self.store = store
    }

    public var body: some View {
        if store.healthKitDenied {
            healthKitDeniedView
        } else {
            monitoringContentView
        }
    }

    // MARK: - Monitoring Content (정상 모니터링)
    private var monitoringContentView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 상태 헤더
                statusHeader

                Divider()

                // 점수 표시
                scoreDisplay
            }
            .padding()
        }
    }

    // MARK: - HealthKit 권한 거부 안내
    private var healthKitDeniedView: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "heart.slash.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .padding(.top, 8)

                Text("심박 접근 필요")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("심박수를 읽으면 더 정확하게 기상 시점을 감지할 수 있어요.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider()

                // 허용 방법 안내
                VStack(alignment: .leading, spacing: 3) {
                    Text("iPhone에서 허용하기")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("설정 → 개인정보 보호 → 건강 → 가뿐 → 심박수 켜기")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

                // 다시 시도
                Button {
                    store.send(.retryHealthKitAuthorization)
                } label: {
                    Label("다시 시도", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                // 모션만 사용 (폴백)
                Button {
                    store.send(.dismissHealthKitError)
                } label: {
                    Text("모션만 사용")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Status Header
    private var statusHeader: some View {
        VStack(spacing: 4) {
            Text(store.monitoringState.rawValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(statusColor)

            // 상태 아이콘
            statusIcon
                .frame(width: 40, height: 40)
        }
    }

    private var statusColor: Color {
        switch store.monitoringState {
        case .idle:
            return .secondary
        case .monitoring:
            return .blue
        case .triggered:
            return .orange
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch store.monitoringState {
        case .idle:
            Image(systemName: "moon.zzz")
                .font(.title2)
                .foregroundColor(.secondary)
        case .monitoring:
            // 맥박 애니메이션
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundColor(.blue)
        case .triggered:
            Image(systemName: "alarm.fill")
                .font(.title2)
                .foregroundColor(.orange)
        }
    }

    // MARK: - Score Display
    private var scoreDisplay: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 현재 점수
            HStack {
                Text("Score")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if let score = store.currentScore {
                    Text(String(format: "%.1f%%", score.score * 100))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(score.score))
                } else {
                    Text("--")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }

            // 점수 게이지
            if let score = store.currentScore {
                ProgressView(value: score.score)
                    .tint(scoreColor(score.score))
            }

            // 컴포넌트 상세
            if let score = store.currentScore {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Motion")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%%", score.components.motionScore * 100))
                            .font(.caption)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("HR")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%%", score.components.heartRateScore * 100))
                            .font(.caption)
                    }
                }
            }

            Divider()

            // Tick 카운트 / 남은 시간
            HStack {
                Text("Tick")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(store.tickCount)")
                    .font(.caption)
            }

            HStack {
                Text("Remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatRemaining(store.remainingSeconds))
                    .font(.caption)
            }

            // 트리거 이벤트
            if let trigger = store.triggerEvent {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Alarm")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(trigger.reason == .smart ? "SMART" : "FORCED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(trigger.reason == .smart ? .green : .orange)
                    }
                    Text(formatTime(trigger.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers
    private func scoreColor(_ score: Double) -> Color {
        let threshold = store.sensitivity.triggerThreshold
        if score >= threshold {
            return .green
        } else if score >= threshold * 0.7 {
            return .yellow
        } else {
            return .secondary
        }
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatTime(_ date: Date) -> String {
        // Calendar.current로 DateComponents를 추출 — 항상 현재 timezone 반영, thread-safe
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let s = cal.component(.second, from: date)
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
