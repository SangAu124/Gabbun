import Foundation
import ComposableArchitecture
import SharedDomain
import SharedTransport

// MARK: - ArmingState
public enum ArmingState: String, Equatable, Sendable {
    case idle = "Idle"
    case armed = "Armed"
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
    }

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .scheduleReceived(schedule, effectiveDate):
                state.schedule = schedule
                state.effectiveDate = effectiveDate
                // 상태 재평가
                updateArmingState(&state)
                return .none

            case .scheduleCancelled:
                state.schedule = nil
                state.effectiveDate = nil
                state.armingState = .idle
                return .none

            case let .tick(now):
                state.now = now
                // 윈도우 시작 1분 전부터 Armed 상태로 전환
                updateArmingState(&state)
                return .none
            }
        }
    }

    // MARK: - Private Helpers
    private func updateArmingState(_ state: inout State) {
        guard let schedule = state.schedule,
              schedule.enabled,
              let windowArmTime = state.windowArmTime,
              let targetWakeTime = state.targetWakeTime else {
            state.armingState = .idle
            return
        }

        // 현재 시각이 windowArmTime(윈도우 시작 1분 전) 이후이고 targetWakeTime 이전이면 Armed
        if state.now >= windowArmTime && state.now < targetWakeTime {
            state.armingState = .armed
        } else {
            state.armingState = .idle
        }
    }
}
