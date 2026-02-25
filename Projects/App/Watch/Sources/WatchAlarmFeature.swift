import Foundation
import ComposableArchitecture
import SharedDomain
import SharedTransport
import WatchKit

// MARK: - AlarmActiveState
public enum AlarmActiveState: Equatable, Sendable {
    case idle                           // 알람 화면 비활성화
    case ringing                        // 알람 울리는 중 (햅틱/사운드)
    case snoozed(resumeAt: Date)        // 스누즈 대기 중 (별도 타이머)
    case dismissed                      // 알람 종료됨 (Stop 눌림)
}

// MARK: - WatchAlarmFeature
@Reducer
public struct WatchAlarmFeature {
    // MARK: - Constants
    private static let snoozeDurationSeconds: Int = 5 * 60 // 5분
    private static let hapticIntervalSeconds: Double = 2.0

    // MARK: - State
    @ObservableState
    public struct State: Equatable {
        public var alarmState: AlarmActiveState = .idle
        public var triggerEvent: TriggerEvent?
        public var snoozeCount: Int = 0

        // 모니터링에서 전달받은 세션 정보
        public var targetWakeTime: Date?
        public var windowStartTime: Date?
        public var recentScores: [ScoreUpdate] = []
        public var now: Date = Date()

        public init(
            alarmState: AlarmActiveState = .idle,
            triggerEvent: TriggerEvent? = nil,
            snoozeCount: Int = 0,
            targetWakeTime: Date? = nil,
            windowStartTime: Date? = nil,
            recentScores: [ScoreUpdate] = [],
            now: Date = Date()
        ) {
            self.alarmState = alarmState
            self.triggerEvent = triggerEvent
            self.snoozeCount = snoozeCount
            self.targetWakeTime = targetWakeTime
            self.windowStartTime = windowStartTime
            self.recentScores = recentScores
            self.now = now
        }

        // Snooze 남은 시간 (초)
        public var snoozeRemainingSeconds: Int {
            guard case let .snoozed(resumeAt) = alarmState else { return 0 }
            return max(0, Int(resumeAt.timeIntervalSince(now)))
        }

        // 디스플레이용 남은 시간 문자열
        public var snoozeRemainingText: String {
            let mins = snoozeRemainingSeconds / 60
            let secs = snoozeRemainingSeconds % 60
            return String(format: "%d:%02d", mins, secs)
        }
    }

    // MARK: - Action
    public enum Action: Sendable {
        // 외부 이벤트
        case alarmTriggered(TriggerEvent, targetWakeTime: Date, windowStartTime: Date, recentScores: [ScoreUpdate])
        case snoozeTriggered // 스누즈 타이머 만료 시 재발화
        case tick(Date)

        // 사용자 액션
        case stopTapped
        case snoozeTapped

        // 내부 이벤트
        case playHaptic
        case sessionSummarySent(Result<Void, Error>)

        // Delegate (부모에게 알림)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case alarmDismissed(WakeSessionSummary)
            case alarmSnoozed
        }
    }

    // MARK: - Dependencies
    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var dateNow

    private enum CancelID {
        case hapticTimer
        case snoozeTimer
    }

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .alarmTriggered(event, targetWakeTime, windowStartTime, recentScores):
                state.alarmState = .ringing
                state.triggerEvent = event
                state.targetWakeTime = targetWakeTime
                state.windowStartTime = windowStartTime
                state.recentScores = recentScores
                state.now = dateNow

                // 햅틱 반복 시작
                return startHapticLoop()

            case .snoozeTriggered:
                // 스누즈 타이머 만료 → 다시 울림
                state.alarmState = .ringing
                return .merge(
                    .cancel(id: CancelID.snoozeTimer),
                    startHapticLoop()
                )

            case let .tick(now):
                state.now = now
                return .none

            case .stopTapped:
                state.alarmState = .dismissed

                // 세션 요약 생성
                let summary = buildSessionSummary(state: state)

                return .merge(
                    .cancel(id: CancelID.hapticTimer),
                    .cancel(id: CancelID.snoozeTimer),
                    sendSessionSummary(summary),
                    .send(.delegate(.alarmDismissed(summary)))
                )

            case .snoozeTapped:
                state.snoozeCount += 1
                // state.now를 기준으로 resumeAt 계산 → UI 표시 시각(snoozeRemainingSeconds)과 일치
                let resumeAt = state.now.addingTimeInterval(Double(Self.snoozeDurationSeconds))
                state.alarmState = .snoozed(resumeAt: resumeAt)

                return .merge(
                    .cancel(id: CancelID.hapticTimer),
                    // 스누즈 타이머 (cooldown과 무관, 단순 재발화)
                    .run { send in
                        try await clock.sleep(for: .seconds(Self.snoozeDurationSeconds))
                        await send(.snoozeTriggered)
                    }
                    .cancellable(id: CancelID.snoozeTimer),
                    .send(.delegate(.alarmSnoozed))
                )

            case .playHaptic:
                // 햅틱 재생 (ringing 상태에서만)
                guard state.alarmState == .ringing else { return .none }
                return .run { _ in WKInterfaceDevice.current().play(.notification) }

            case .sessionSummarySent(.success):
                return .none

            case let .sessionSummarySent(.failure(error)):
                return .run { _ in
                    print("[AlarmFeature] sessionSummary 전송 실패: \(error.localizedDescription)")
                }

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Private Helpers

    private func startHapticLoop() -> Effect<Action> {
        // 즉시 1회 + 반복 타이머 — 모두 .run으로 분리하여 Reducer 순수성 유지
        return .merge(
            .run { _ in WKInterfaceDevice.current().play(.notification) },
            .run { send in
                for await _ in clock.timer(interval: .seconds(Self.hapticIntervalSeconds)) {
                    await send(.playHaptic)
                }
            }
            .cancellable(id: CancelID.hapticTimer)
        )
    }

    private func buildSessionSummary(state: State) -> WakeSessionSummary {
        guard let triggerEvent = state.triggerEvent,
              let windowStart = state.windowStartTime,
              let targetWake = state.targetWakeTime else {
            // Fallback: 세션 필수 데이터가 없는 비정상 경로 — 실제 발화 시각(now)으로 기록
            let fallbackTime = state.now
            print("[AlarmFeature] buildSessionSummary: 세션 메타데이터 부재 — fallback 사용 (triggerEvent=\(state.triggerEvent != nil), windowStart=\(state.windowStartTime != nil), targetWake=\(state.targetWakeTime != nil))")
            return WakeSessionSummary(
                windowStartAt: fallbackTime,
                windowEndAt: fallbackTime,
                firedAt: fallbackTime,
                reason: .forced,
                scoreAtFire: 0
            )
        }

        // Best score 찾기
        let bestScore = state.recentScores.max(by: { $0.score < $1.score })

        // 배터리 소모 추정: 모니터링 윈도우 1분당 약 0.5% (워크아웃 세션 유지 비용)
        let windowMinutes = targetWake.timeIntervalSince(windowStart) / 60.0
        let batteryImpactEstimate = Int((windowMinutes * 0.5).rounded())

        return WakeSessionSummary(
            windowStartAt: windowStart,
            windowEndAt: targetWake,
            firedAt: triggerEvent.timestamp,
            reason: triggerEvent.reason == .smart ? .smart : .forced,
            scoreAtFire: triggerEvent.score,
            bestCandidateAt: bestScore?.timestamp,
            bestScore: bestScore?.score,
            batteryImpactEstimate: batteryImpactEstimate
        )
    }

    private func sendSessionSummary(_ summary: WakeSessionSummary) -> Effect<Action> {
        .run { send in
            await send(.sessionSummarySent(Result {
                let payload = SessionSummaryPayload(summary: summary)
                let envelope = Envelope(type: .sessionSummary, payload: payload)
                let message = try TransportMessage(envelope: envelope)
                try wcSessionClient.updateContext(message)
            }))
        }
    }
}
