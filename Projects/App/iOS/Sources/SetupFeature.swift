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
        public var isActivated: Bool = false
        public var lastSyncAt: Date?
        public var errorMessage: String?
        public var isSyncing: Bool = false

        // 폴백 알림 권한 상태
        public var notificationPermissionGranted: Bool = false

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
        case connectionStatusUpdated(isReachable: Bool, isActivated: Bool)

        // 폴백 알림
        case notificationPermissionResponse(Bool)

        // Watch → iOS 메시지 수신
        case messageReceived(TransportMessage)
        case sessionSummaryReceived(WakeSessionSummary)
    }

    // MARK: - Dependencies
    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.date.now) var now
    @Dependency(\.continuousClock) var clock

    private enum CancelID {
        case connectionMonitor
        case messageStream
    }

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    // WCSession 활성화
                    .run { _ in await wcSessionClient.activate() },
                    // 연결 상태 모니터링
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.updateConnectionStatus)
                        }
                    }
                    .cancellable(id: CancelID.connectionMonitor),
                    // Watch → iOS 메시지 스트림 수신
                    .run { send in
                        for await message in wcSessionClient.messages() {
                            await send(.messageReceived(message))
                        }
                    }
                    .cancellable(id: CancelID.messageStream),
                    // 알림 권한 요청
                    .run { send in
                        let granted = await notificationClient.requestAuthorization()
                        await send(.notificationPermissionResponse(granted))
                    }
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

                // 기상 시각이 오늘 이미 지났으면 내일 날짜를 effectiveDate로 사용
                let calendar = Calendar.current
                var todayWakeComponents = calendar.dateComponents([.year, .month, .day], from: now)
                todayWakeComponents.hour = state.wakeTimeHour
                todayWakeComponents.minute = state.wakeTimeMinute
                todayWakeComponents.second = 0

                let effectiveDateBase: Date
                if let todayWakeTime = calendar.date(from: todayWakeComponents), todayWakeTime <= now {
                    effectiveDateBase = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                } else {
                    effectiveDateBase = now
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let effectiveDate = dateFormatter.string(from: effectiveDateBase)

                let payload = UpdateSchedulePayload(
                    schedule: schedule,
                    effectiveDate: effectiveDate
                )

                let envelope = Envelope(
                    type: .updateSchedule,
                    payload: payload
                )

                // 기상 시각 계산 (폴백 알림용)
                let wakeHour = state.wakeTimeHour
                let wakeMinute = state.wakeTimeMinute
                let isEnabled = state.enabled
                let permissionGranted = state.notificationPermissionGranted

                return .run { send in
                    // Watch로 스케줄 전송
                    await send(.syncResponse(Result {
                        let message = try TransportMessage(envelope: envelope)
                        try wcSessionClient.updateContext(message)
                    }))

                    // 폴백 알림 스케줄 (enabled 상태이고 권한 있을 때)
                    if isEnabled && permissionGranted {
                        // effectiveDateBase 기준으로 날짜 추출 (내일일 수 있음)
                        var components = calendar.dateComponents([.year, .month, .day], from: effectiveDateBase)
                        components.hour = wakeHour
                        components.minute = wakeMinute
                        if let wakeTime = calendar.date(from: components) {
                            await notificationClient.scheduleWakeUpFallback(wakeTime)
                        }
                    } else if !isEnabled {
                        await notificationClient.cancelWakeUpFallback()
                    }
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
                let isActivated = wcSessionClient.isActivated()
                return .send(.connectionStatusUpdated(isReachable: isReachable, isActivated: isActivated))

            case .connectionStatusUpdated(let isReachable, let isActivated):
                state.isReachable = isReachable
                state.isActivated = isActivated
                return .none

            case .notificationPermissionResponse(let granted):
                state.notificationPermissionGranted = granted
                return .none

            // MARK: - Watch → iOS 메시지 처리

            case let .messageReceived(message):
                // alarmFired 수신 시 폴백 알림 즉시 취소
                if let envelope: Envelope<AlarmFiredEventPayload> = try? message.decode(),
                   envelope.type == .alarmFired {
                    return .run { _ in await notificationClient.cancelWakeUpFallback() }
                }
                // sessionSummary 수신 시 폴백 알림 취소 + 리포트 업데이트
                if let envelope: Envelope<SessionSummaryPayload> = try? message.decode(),
                   envelope.type == .sessionSummary {
                    return .merge(
                        .run { _ in await notificationClient.cancelWakeUpFallback() },
                        .send(.sessionSummaryReceived(envelope.payload.summary))
                    )
                }
                return .none

            case .sessionSummaryReceived:
                // 부모 AppFeature에서 처리 (ReportFeature로 라우팅)
                return .none
            }
        }
    }
}
