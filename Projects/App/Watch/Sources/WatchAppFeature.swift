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
        public var isCompanionReachable: Bool = false

        public init() {}
    }

    // MARK: - Action
    public enum Action: Sendable {
        case onAppear
        case arming(WatchArmingFeature.Action)
        case messageReceived(TransportMessage)
        case tick
        case updateReachability
        case reachabilityUpdated(Bool)
    }

    // MARK: - Dependencies
    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.date.now) var now
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
                return .send(.arming(.tick(now)))

            case .updateReachability:
                let isReachable = wcSessionClient.isReachable()
                return .send(.reachabilityUpdated(isReachable))

            case let .reachabilityUpdated(isReachable):
                state.isCompanionReachable = isReachable
                return .none

            case .arming:
                return .none
            }
        }
    }

    // MARK: - Message Handling
    private func handleMessage(_ message: TransportMessage, state: inout State) -> Effect<Action> {
        // 메시지 타입 먼저 확인
        guard let typeEnvelope: Envelope<PingPayload> = try? message.decode(),
              let messageType = MessageType(rawValue: typeEnvelope.type.rawValue) else {
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
