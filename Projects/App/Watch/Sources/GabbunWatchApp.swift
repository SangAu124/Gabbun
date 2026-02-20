import SwiftUI
import ComposableArchitecture
import SharedDomain
import SharedAlgorithm
import SharedTransport

@main
struct GabbunWatchApp: App {
    let store: StoreOf<WatchAppFeature>

    init() {
        self.store = Store(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        } withDependencies: {
            $0.wcSessionClient = .liveValue
            $0.heartRateClient = .liveValue
            $0.motionClient = .liveValue
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchMainView(store: store)
                .onAppear {
                    store.send(.onAppear)
                }
        }
    }
}

// MARK: - WatchMainView
struct WatchMainView: View {
    let store: StoreOf<WatchAppFeature>

    var body: some View {
        // 알람 활성화 시 알람 화면 우선 표시
        if store.isAlarmActive {
            WatchAlarmView(store: store.scope(state: \.alarm, action: \.alarm))
        } else {
            // 상태에 따라 뷰 전환
            switch store.arming.armingState {
            case .idle, .armed:
                // 스케줄/대기 화면
                WatchArmingView(store: store.scope(state: \.arming, action: \.arming))

            case .monitoring, .triggered:
                // 모니터링 화면
                WatchMonitoringView(
                    store: store.scope(state: \.monitoring, action: \.monitoring)
                )
            }
        }
    }
}

#Preview("Idle") {
    WatchArmingView(
        store: Store(initialState: WatchArmingFeature.State()) {
            WatchArmingFeature()
        }
    )
}

#Preview("Monitoring") {
    WatchMonitoringView(
        store: Store(initialState: WatchMonitoringFeature.State()) {
            WatchMonitoringFeature()
        }
    )
}

#Preview("Alarm Ringing") {
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
