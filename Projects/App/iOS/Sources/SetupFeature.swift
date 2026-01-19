import Foundation
import ComposableArchitecture
import SharedDomain
import SharedTransport

// MARK: - SetupFeature
@Reducer
public struct SetupFeature {
    // MARK: - State
    @ObservableState
    public struct State: Equatable {
        public var wakeTimeHour: Int = 7
        public var wakeTimeMinute: Int = 30
        public var windowMinutes: Int = 30
        public var sensitivity: AlarmSchedule.Sensitivity = .balanced
        public var enabled: Bool = true

        public var isReachable: Bool = false
        public var lastSyncAt: Date?
        public var errorMessage: String?
        public var isSyncing: Bool = false

        public init(
            wakeTimeHour: Int = 7,
            wakeTimeMinute: Int = 30,
            windowMinutes: Int = 30,
            sensitivity: AlarmSchedule.Sensitivity = .balanced,
            enabled: Bool = true
        ) {
            self.wakeTimeHour = wakeTimeHour
            self.wakeTimeMinute = wakeTimeMinute
            self.windowMinutes = windowMinutes
            self.sensitivity = sensitivity
            self.enabled = enabled
        }
    }

    // MARK: - Action
    public enum Action: Sendable {
        case onAppear
        case wakeTimeHourChanged(Int)
        case wakeTimeMinuteChanged(Int)
        case windowMinutesChanged(Int)
        case sensitivityChanged(AlarmSchedule.Sensitivity)
        case enabledToggled
        case syncButtonTapped
        case syncResponse(Result<Void, Error>)
        case updateConnectionStatus
        case connectionStatusUpdated(isReachable: Bool)
    }

    // MARK: - Dependencies
    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.date.now) var now
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case connectionMonitor }

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // WCSession 활성화 및 연결 상태 모니터링 시작
                return .merge(
                    .run { send in
                        await wcSessionClient.activate()
                    },
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.updateConnectionStatus)
                        }
                    }
                    .cancellable(id: CancelID.connectionMonitor)
                )

            case .wakeTimeHourChanged(let hour):
                state.wakeTimeHour = hour
                return .none

            case .wakeTimeMinuteChanged(let minute):
                state.wakeTimeMinute = minute
                return .none

            case .windowMinutesChanged(let minutes):
                state.windowMinutes = minutes
                return .none

            case .sensitivityChanged(let sensitivity):
                state.sensitivity = sensitivity
                return .none

            case .enabledToggled:
                state.enabled.toggle()
                return .none

            case .syncButtonTapped:
                guard !state.isSyncing else { return .none }

                state.isSyncing = true
                state.errorMessage = nil

                let schedule = AlarmSchedule(
                    wakeTimeLocal: String(format: "%02d:%02d", state.wakeTimeHour, state.wakeTimeMinute),
                    windowMinutes: state.windowMinutes,
                    sensitivity: state.sensitivity,
                    enabled: state.enabled
                )

                // effectiveDate: 오늘 날짜 (YYYY-MM-DD)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let effectiveDate = dateFormatter.string(from: now)

                let payload = UpdateSchedulePayload(
                    schedule: schedule,
                    effectiveDate: effectiveDate
                )

                let envelope = Envelope(
                    type: .updateSchedule,
                    payload: payload
                )

                return .run { send in
                    await send(.syncResponse(Result {
                        let message = try TransportMessage(envelope: envelope)
                        try await wcSessionClient.send(message)
                    }))
                }

            case .syncResponse(.success):
                state.isSyncing = false
                state.lastSyncAt = now
                state.errorMessage = nil
                return .none

            case .syncResponse(.failure(let error)):
                state.isSyncing = false
                state.errorMessage = "동기화 실패: \(error.localizedDescription)"
                return .none

            case .updateConnectionStatus:
                let isReachable = wcSessionClient.isReachable()
                return .send(.connectionStatusUpdated(isReachable: isReachable))

            case .connectionStatusUpdated(let isReachable):
                state.isReachable = isReachable
                return .none
            }
        }
    }
}
