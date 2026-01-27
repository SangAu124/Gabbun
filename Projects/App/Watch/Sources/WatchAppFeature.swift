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
                state.now = dateNow
                return .merge(
                    .send(.arming(.tick(dateNow))),
                    .send(.monitoring(.tick(dateNow))),
                    .send(.alarm(.tick(dateNow)))
                )

            case .updateReachability:
                let isReachable = wcSessionClient.isReachable()
                return .send(.reachabilityUpdated(isReachable))

            case let .reachabilityUpdated(isReachable):
                state.isCompanionReachable = isReachable
                return .none

            // MARK: - Arming Delegate Actions
            case let .arming(.delegate(.startMonitoring(targetWakeTime, windowStartTime))):
                // 모니터링 시작
                return .send(.monitoring(.startMonitoring(
                    targetWakeTime: targetWakeTime,
                    windowStartTime: windowStartTime
                )))

            case .arming(.delegate(.alarmTriggered)):
                // 알람 발화됨 (arming에서 triggered로 전환 필요 시)
                return .none

            case .arming(.delegate(.sessionEnded)):
                // 세션 종료 → 모니터링 중지
                return .send(.monitoring(.stopMonitoring))

            case .arming:
                return .none

            // MARK: - Monitoring Actions
            case let .monitoring(.triggerDetected(event)):
                // 알람 트리거 → arming 상태 업데이트 + 알람 화면 활성화
                WatchArmingFeature.setTriggered(&state.arming)

                // 알람 발화
                return .send(.alarm(.alarmTriggered(
                    event,
                    targetWakeTime: state.monitoring.targetWakeTime ?? Date(),
                    windowStartTime: state.monitoring.windowStartTime ?? Date(),
                    recentScores: state.monitoring.recentScores
                )))

            case .monitoring:
                return .none

            // MARK: - Alarm Delegate Actions
            case let .alarm(.delegate(.alarmDismissed(summary))):
                // 알람 종료 → 세션 종료 처리
                // Arming 상태를 idle로 전환
                state.arming.armingState = .idle
                state.arming.schedule = nil
                state.arming.effectiveDate = nil

                // 모니터링 중지
                return .send(.monitoring(.stopMonitoring))

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
        // 메시지 타입 먼저 확인
        guard let typeEnvelope: Envelope<PingPayload> = try? message.decode(),
              let _ = MessageType(rawValue: typeEnvelope.type.rawValue) else {
            // fallback: raw type 파싱 시도
            return parseAndHandleMessage(message, state: &state)
        }

        return parseAndHandleMessage(message, state: &state)
    }

    private func parseAndHandleMessage(_ message: TransportMessage, state: inout State) -> Effect<Action> {
        // updateSchedule 메시지 처리
        if let envelope: Envelope<UpdateSchedulePayload> = try? message.decode() {
            if envelope.type == .updateSchedule {
                let payload = envelope.payload
                return .send(.arming(.scheduleReceived(
                    schedule: payload.schedule,
                    effectiveDate: payload.effectiveDate
                )))
            }
        }

        // cancelSchedule 메시지 처리
        if let envelope: Envelope<CancelSchedulePayload> = try? message.decode() {
            if envelope.type == .cancelSchedule {
                return .send(.arming(.scheduleCancelled))
            }
        }

        // ping 메시지 처리 (무시)
        if let _: Envelope<PingPayload> = try? message.decode() {
            return .none
        }

        return .none
    }
}
