import Foundation
import ComposableArchitecture
import SharedDomain
import SharedAlgorithm
import SharedTransport

// MARK: - MonitoringState
public enum MonitoringState: String, Equatable, Sendable {
    case idle = "Idle"               // 모니터링 대기 중
    case monitoring = "Monitoring"   // 모니터링 진행 중
    case triggered = "Triggered"     // 알람 발화됨
}

// MARK: - WatchMonitoringFeature
@Reducer
public struct WatchMonitoringFeature {
    // MARK: - State
    @ObservableState
    public struct State: Equatable {
        public var monitoringState: MonitoringState = .idle
        public var simulationMode: SensorSimulationMode = .deepSleep

        // 알고리즘 입력
        public var motionSamples: [MotionSample] = []
        public var heartRateSamples: [HeartRateSample] = []
        public var recentScores: [ScoreUpdate] = []

        // 알고리즘 출력
        public var currentScore: WakeabilityScore?
        public var lastTriggerTime: Date?
        public var triggerEvent: TriggerEvent?

        // 스케줄 정보 (WatchArmingFeature에서 전달)
        public var targetWakeTime: Date?
        public var windowStartTime: Date?

        // 타이머
        public var tickCount: Int = 0

        public init() {}

        // 경과 시간 (윈도우 시작 기준)
        public var elapsedSeconds: Int {
            guard let windowStart = windowStartTime else { return 0 }
            return max(0, tickCount)
        }

        // 현재 시각 (외부에서 주입)
        public var now: Date = Date()

        // 남은 시간 (목표 기상 시각 기준)
        public var remainingSeconds: Int {
            guard let target = targetWakeTime else { return 0 }
            return max(0, Int(target.timeIntervalSince(now)))
        }
    }

    // MARK: - Action
    public enum Action: Sendable {
        // 외부 이벤트
        case startMonitoring(targetWakeTime: Date, windowStartTime: Date)
        case stopMonitoring
        case setSimulationMode(SensorSimulationMode)
        case tick(Date) // 매초 tick (now 업데이트용)

        // 내부 타이머 (30초 tick)
        case algorithmTick(Date)

        // 알고리즘 결과
        case scoreComputed(WakeabilityScore, Date)
        case triggerDetected(TriggerEvent)

        // iOS 전송 완료
        case alarmFiredSent(Result<Void, Error>)
    }

    // MARK: - Dependencies
    @Dependency(\.sensorSimulator) var sensorSimulator
    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID {
        case algorithmTimer
    }

    // MARK: - Algorithm
    private let algorithm = WakeabilityAlgorithm()

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startMonitoring(targetWakeTime, windowStartTime):
                state.monitoringState = .monitoring
                state.targetWakeTime = targetWakeTime
                state.windowStartTime = windowStartTime
                state.tickCount = 0
                state.recentScores = []
                state.currentScore = nil
                state.triggerEvent = nil
                state.motionSamples = []
                state.heartRateSamples = []

                // 30초 타이머 시작
                return .run { send in
                    for await _ in clock.timer(interval: .seconds(30)) {
                        await send(.algorithmTick(Date()))
                    }
                }
                .cancellable(id: CancelID.algorithmTimer)

            case .stopMonitoring:
                state.monitoringState = .idle
                state.tickCount = 0
                return .cancel(id: CancelID.algorithmTimer)

            case let .setSimulationMode(mode):
                state.simulationMode = mode
                return .none

            case let .tick(now):
                state.now = now
                return .none

            case let .algorithmTick(now):
                guard state.monitoringState == .monitoring,
                      let targetWakeTime = state.targetWakeTime else {
                    return .none
                }

                state.tickCount += 1

                // 센서 시뮬레이터에서 샘플 생성
                let motionSamples = sensorSimulator.generateMotionSamples(state.simulationMode, now)
                let hrSamples = sensorSimulator.generateHeartRateSamples(state.simulationMode, now)

                // 샘플 업데이트 (누적 대신 최신 윈도우만 사용)
                state.motionSamples = motionSamples
                state.heartRateSamples = hrSamples

                // 점수 계산
                let score = algorithm.computeScore(
                    motionSamples: motionSamples,
                    hrSamples: hrSamples,
                    currentTime: now
                )

                // 점수 기록
                let scoreUpdate = ScoreUpdate(
                    score: score.score,
                    components: score.components,
                    timestamp: now
                )
                state.recentScores.append(scoreUpdate)

                // 최근 10개만 유지 (메모리 관리)
                if state.recentScores.count > 10 {
                    state.recentScores.removeFirst()
                }

                state.currentScore = score

                // 트리거 판단
                if let triggerEvent = algorithm.evaluateTrigger(
                    recentScores: state.recentScores,
                    lastTriggerTime: state.lastTriggerTime,
                    currentTime: now,
                    wakeTime: targetWakeTime
                ) {
                    return .send(.triggerDetected(triggerEvent))
                }

                return .none

            case let .scoreComputed(score, timestamp):
                state.currentScore = score
                return .none

            case let .triggerDetected(event):
                state.triggerEvent = event
                state.lastTriggerTime = event.timestamp
                state.monitoringState = .triggered

                // 타이머 취소
                // iOS로 alarmFired 메시지 전송
                guard let targetWakeTime = state.targetWakeTime else {
                    return .cancel(id: CancelID.algorithmTimer)
                }

                let payload = AlarmFiredEventPayload(
                    targetWakeAt: targetWakeTime,
                    firedAt: event.timestamp,
                    reason: event.reason == .smart ? .smart : .forced,
                    scoreAtFire: event.score,
                    components: event.components,
                    cooldownApplied: false
                )

                return .merge(
                    .cancel(id: CancelID.algorithmTimer),
                    .run { send in
                        await send(.alarmFiredSent(Result {
                            let envelope = Envelope(type: .alarmFired, payload: payload)
                            let message = try TransportMessage(envelope: envelope)
                            try wcSessionClient.updateContext(message)
                        }))
                    }
                )

            case .alarmFiredSent(.success):
                // 전송 성공
                return .none

            case let .alarmFiredSent(.failure(error)):
                // 전송 실패 (로그만, 알람은 계속 울림)
                print("[MonitoringFeature] alarmFired 전송 실패: \(error.localizedDescription)")
                return .none
            }
        }
    }
}
