import Foundation
import ComposableArchitecture
import SharedDomain
import SharedTransport

// MARK: - ArmingState
public enum ArmingState: String, Equatable, Sendable {
    case idle = "Idle"              // 스케줄 없음 또는 비활성화
    case armed = "Armed"            // 윈도우 시작 대기 중 (windowArmTime ~ windowStartTime)
    case monitoring = "Monitoring"  // 모니터링 진행 중 (windowStartTime ~ trigger/targetWakeTime)
    case triggered = "Triggered"    // 알람 발화됨
}

// MARK: - WatchArmingFeature
@Reducer
public struct WatchArmingFeature {
    // MARK: - State
    @ObservableState
    public struct State: Equatable {
        public var schedule: AlarmSchedule?
        public var effectiveDate: String? // "YYYY-MM-DD"
        public var armingState: ArmingState = .idle
        public var now: Date = Date()

        // Computed: 목표 기상 시각 (effectiveDate + wakeTimeLocal)
        public var targetWakeTime: Date? {
            guard let schedule = schedule,
                  let effectiveDate = effectiveDate else { return nil }
            return Self.parseTargetWakeTime(
                effectiveDate: effectiveDate,
                wakeTimeLocal: schedule.wakeTimeLocal
            )
        }

        // Computed: 윈도우 시작 시각 (targetWakeTime - windowMinutes)
        public var windowStartTime: Date? {
            guard let target = targetWakeTime,
                  let schedule = schedule else { return nil }
            return target.addingTimeInterval(-Double(schedule.windowMinutes * 60))
        }

        // Computed: 윈도우 시작 1분 전 시각
        public var windowArmTime: Date? {
            guard let windowStart = windowStartTime else { return nil }
            return windowStart.addingTimeInterval(-60) // 1분 전
        }

        public var enabled: Bool {
            schedule?.enabled ?? false
        }

        public init() {}

        // Helper: effectiveDate + wakeTimeLocal → Date
        private static func parseTargetWakeTime(effectiveDate: String, wakeTimeLocal: String) -> Date? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            formatter.timeZone = TimeZone.current
            let dateString = "\(effectiveDate) \(wakeTimeLocal)"
            return formatter.date(from: dateString)
        }
    }

    // MARK: - Action
    public enum Action: Sendable {
        case scheduleReceived(schedule: AlarmSchedule, effectiveDate: String)
        case scheduleCancelled
        case tick(Date)

        // 부모 Reducer가 내려보내는 상태 전환 명령
        case setTriggered
        case resetSession

        // 상태 전환 이벤트 (부모에게 전달)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case startMonitoring(targetWakeTime: Date, windowStartTime: Date, sensitivity: AlarmSchedule.Sensitivity)
            case alarmTriggered
            case sessionEnded
        }
    }

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .scheduleReceived(schedule, effectiveDate):
                state.schedule = schedule
                state.effectiveDate = effectiveDate
                // 상태 재평가
                return evaluateStateChange(&state)

            case .scheduleCancelled:
                state.schedule = nil
                state.effectiveDate = nil
                state.armingState = .idle
                return .none

            case let .tick(now):
                state.now = now
                return evaluateStateChange(&state)

            case .setTriggered:
                state.armingState = .triggered
                return .none

            case .resetSession:
                state.armingState = .idle
                state.schedule = nil
                state.effectiveDate = nil
                return .none

            case .delegate:
                // 부모에서 처리
                return .none
            }
        }
    }

    // MARK: - Private Helpers
    private func evaluateStateChange(_ state: inout State) -> Effect<Action> {
        guard let schedule = state.schedule,
              schedule.enabled,
              let windowArmTime = state.windowArmTime,
              let windowStartTime = state.windowStartTime,
              let targetWakeTime = state.targetWakeTime else {
            state.armingState = .idle
            return .none
        }

        let now = state.now
        let previousState = state.armingState

        // 목표 시각 이후 → Idle (세션 종료)
        if now >= targetWakeTime {
            if previousState == .monitoring {
                state.armingState = .idle
                return .send(.delegate(.sessionEnded))
            }
            state.armingState = .idle
            return .none
        }

        // 윈도우 시작 이후 → Monitoring
        if now >= windowStartTime {
            if previousState != .monitoring && previousState != .triggered {
                state.armingState = .monitoring
                let sensitivity = schedule.sensitivity
                return .send(.delegate(.startMonitoring(
                    targetWakeTime: targetWakeTime,
                    windowStartTime: windowStartTime,
                    sensitivity: sensitivity
                )))
            }
            return .none
        }

        // 윈도우 시작 1분 전 이후 → Armed
        if now >= windowArmTime {
            state.armingState = .armed
            return .none
        }

        // 그 외 → Idle
        state.armingState = .idle
        return .none
    }

}
