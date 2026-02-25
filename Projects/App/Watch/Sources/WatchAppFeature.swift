import Foundation
import ComposableArchitecture
import SharedDomain
import SharedTransport

// MARK: - WatchAppFeature (Root)
@Reducer
public struct WatchAppFeature {
    // MARK: - State
    @ObservableState
    public struct State: Equatable {
        public var arming: WatchArmingFeature.State = .init()
        public var monitoring: WatchMonitoringFeature.State = .init()
        public var alarm: WatchAlarmFeature.State = .init()
        public var isCompanionReachable: Bool = false
        public var now: Date = Date()

        // 알람 화면 표시 여부
        public var isAlarmActive: Bool {
            switch alarm.alarmState {
            case .ringing, .snoozed:
                return true
            case .idle, .dismissed:
                return false
            }
        }

        public init() {}
    }

    // MARK: - Action
    public enum Action: Sendable {
        case onAppear
        case arming(WatchArmingFeature.Action)
        case monitoring(WatchMonitoringFeature.Action)
        case alarm(WatchAlarmFeature.Action)
        case messageReceived(TransportMessage)
        case tick
        case updateReachability
        case reachabilityUpdated(Bool)
    }

    // MARK: - Dependencies
    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.date.now) var dateNow
    @Dependency(\.continuousClock) var clock

    private enum CancelID {
        case messageStream
        case tickTimer
        case reachabilityMonitor
    }

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Scope(state: \.arming, action: \.arming) {
            WatchArmingFeature()
        }

        Scope(state: \.monitoring, action: \.monitoring) {
            WatchMonitoringFeature()
        }

        Scope(state: \.alarm, action: \.alarm) {
            WatchAlarmFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    // WCSession 활성화 및 기존 context 확인
                    .run { send in
                        await wcSessionClient.activate()
                        // 앱 시작 시 이미 수신된 applicationContext 확인
                        if let existingContext = wcSessionClient.receivedContext() {
                            await send(.messageReceived(existingContext))
                        }
                    },
                    // 메시지 수신 스트림 구독 (applicationContext 변경 시에도 yield됨)
                    .run { send in
                        for await message in wcSessionClient.messages() {
                            await send(.messageReceived(message))
                        }
                    }
                    .cancellable(id: CancelID.messageStream),
                    // 1초마다 tick (상태 업데이트용)
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.tick)
                        }
                    }
                    .cancellable(id: CancelID.tickTimer),
                    // 연결 상태 모니터링
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(2)) {
                            await send(.updateReachability)
                        }
                    }
                    .cancellable(id: CancelID.reachabilityMonitor)
                )

            case let .messageReceived(message):
                return handleMessage(message, state: &state)

            case .tick:
                let now = dateNow
                state.now = now
                return .merge(
                    .send(.arming(.tick(now))),
                    .send(.monitoring(.tick(now))),
                    .send(.alarm(.tick(now)))
                )

            case .updateReachability:
                let isReachable = wcSessionClient.isReachable()
                return .send(.reachabilityUpdated(isReachable))

            case let .reachabilityUpdated(isReachable):
                state.isCompanionReachable = isReachable
                return .none

            // MARK: - Arming Delegate Actions
            case let .arming(.delegate(.startMonitoring(targetWakeTime, windowStartTime, sensitivity))):
                // 모니터링 시작 (sensitivity까지 전달)
                return .send(.monitoring(.startMonitoring(
                    targetWakeTime: targetWakeTime,
                    windowStartTime: windowStartTime,
                    sensitivity: sensitivity
                )))

            case .arming(.delegate(.sessionEnded)):
                // 세션 종료 → 모니터링 중지
                return .send(.monitoring(.stopMonitoring))

            case .arming:
                return .none

            // MARK: - Monitoring Actions
            case let .monitoring(.triggerDetected(event)):
                // 알람 트리거 → arming 상태 업데이트 + 알람 화면 활성화
                // ?? Date() 폴백은 잘못된 세션 데이터를 리포트에 저장하므로 guard로 명시적 처리
                guard let targetWakeTime = state.monitoring.targetWakeTime,
                      let windowStartTime = state.monitoring.windowStartTime else {
                    return .run { _ in
                        print("[WatchAppFeature] triggerDetected: targetWakeTime 또는 windowStartTime 부재 — 알람 발화 스킵")
                    }
                }
                let recentScores = state.monitoring.recentScores
                return .merge(
                    .send(.arming(.setTriggered)),
                    .send(.alarm(.alarmTriggered(
                        event,
                        targetWakeTime: targetWakeTime,
                        windowStartTime: windowStartTime,
                        recentScores: recentScores
                    )))
                )

            case .monitoring:
                return .none

            // MARK: - Alarm Delegate Actions
            case .alarm(.delegate(.alarmDismissed)):
                // 알람 종료 → arming 리셋 + 모니터링 중지 (자식 Reducer에 액션으로 위임)
                return .merge(
                    .send(.arming(.resetSession)),
                    .send(.monitoring(.stopMonitoring))
                )

            case .alarm(.delegate(.alarmSnoozed)):
                // 스누즈 → 별도 처리 없음 (알람 화면 유지, cooldown과 무관)
                return .none

            case .alarm:
                return .none
            }
        }
    }

    // MARK: - Message Handling
    private func handleMessage(_ message: TransportMessage, state: inout State) -> Effect<Action> {
        if let envelope: Envelope<UpdateSchedulePayload> = try? message.decode(),
           envelope.type == .updateSchedule {
            let payload = envelope.payload
            return .send(.arming(.scheduleReceived(
                schedule: payload.schedule,
                effectiveDate: payload.effectiveDate
            )))
        } else if let envelope: Envelope<CancelSchedulePayload> = try? message.decode(),
                  envelope.type == .cancelSchedule {
            return .send(.arming(.scheduleCancelled))
        } else {
            return .run { _ in
                print("[WatchAppFeature] 처리 불가 메시지 수신 — 향후 메시지 타입 추가 시 핸들러 등록 필요")
            }
        }
    }
}
