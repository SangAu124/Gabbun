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
        public var sensitivity: AlarmSchedule.Sensitivity = .balanced

        // 알고리즘 입력 (스트리밍으로 누적)
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

        // 경과 시간 (tick 기준)
        public var elapsedSeconds: Int {
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
        case startMonitoring(targetWakeTime: Date, windowStartTime: Date, sensitivity: AlarmSchedule.Sensitivity)
        case stopMonitoring
        case tick(Date) // 매초 tick (now 업데이트용)

        // 실시간 센서 스트림
        case heartRateSampleReceived(HeartRateSample)
        case motionSampleReceived(MotionSample)

        // 내부 타이머 (30초 tick)
        case algorithmTick(Date)

        // 알고리즘 결과
        case scoreComputed(WakeabilityScore, Date)
        case triggerDetected(TriggerEvent)

        // iOS 전송 완료
        case alarmFiredSent(Result<Void, Error>)
    }

    // MARK: - Dependencies
    @Dependency(\.heartRateClient) var heartRateClient
    @Dependency(\.motionClient) var motionClient
    @Dependency(\.wcSessionClient) var wcSessionClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID {
        case algorithmTimer
        case heartRateStream
        case motionStream
    }

    // 샘플 버퍼 유지 시간 (알고리즘 윈도우보다 넉넉하게)
    private static let bufferWindowSeconds: TimeInterval = 150.0

    // MARK: - Reducer
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startMonitoring(targetWakeTime, windowStartTime, sensitivity):
                state.monitoringState = .monitoring
                state.targetWakeTime = targetWakeTime
                state.windowStartTime = windowStartTime
                state.sensitivity = sensitivity
                state.tickCount = 0
                state.recentScores = []
                state.currentScore = nil
                state.triggerEvent = nil
                state.motionSamples = []
                state.heartRateSamples = []

                return .merge(
                    // 30초 알고리즘 타이머
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(30)) {
                            await send(.algorithmTick(Date()))
                        }
                    }
                    .cancellable(id: CancelID.algorithmTimer),

                    // 심박 스트리밍
                    .run { [heartRateClient] send in
                        try await heartRateClient.startWorkoutSession()
                        for await sample in heartRateClient.heartRateSamples() {
                            await send(.heartRateSampleReceived(sample))
                        }
                    }
                    .cancellable(id: CancelID.heartRateStream),

                    // 가속도 스트리밍
                    .run { [motionClient] send in
                        try await motionClient.startUpdates()
                        for await sample in motionClient.motionSamples() {
                            await send(.motionSampleReceived(sample))
                        }
                    }
                    .cancellable(id: CancelID.motionStream)
                )

            case .stopMonitoring:
                state.monitoringState = .idle
                state.tickCount = 0
                return .merge(
                    .cancel(id: CancelID.algorithmTimer),
                    .cancel(id: CancelID.heartRateStream),
                    .cancel(id: CancelID.motionStream),
                    .run { [motionClient] _ in await motionClient.stopUpdates() }
                )

            case let .tick(now):
                state.now = now
                return .none

            // MARK: - 실시간 센서 샘플 누적

            case let .heartRateSampleReceived(sample):
                state.heartRateSamples.append(sample)
                // 오래된 샘플 제거 (bufferWindow 이전 항목)
                let cutoff = Date().addingTimeInterval(-Self.bufferWindowSeconds)
                state.heartRateSamples = state.heartRateSamples.filter { $0.timestamp >= cutoff }
                return .none

            case let .motionSampleReceived(sample):
                state.motionSamples.append(sample)
                // 오래된 샘플 제거
                let cutoff = Date().addingTimeInterval(-Self.bufferWindowSeconds)
                state.motionSamples = state.motionSamples.filter { $0.timestamp >= cutoff }
                return .none

            // MARK: - 알고리즘 틱 (30초)

            case let .algorithmTick(now):
                guard state.monitoringState == .monitoring,
                      let targetWakeTime = state.targetWakeTime else {
                    return .none
                }

                state.tickCount += 1

                // 민감도에 따른 임계값 결정
                let threshold = sensitivityThreshold(state.sensitivity)
                let algorithm = WakeabilityAlgorithm(
                    triggerDecider: TriggerDecider(threshold: threshold)
                )

                // 점수 계산 (누적된 실제 센서 샘플 사용)
                let score = algorithm.computeScore(
                    motionSamples: state.motionSamples,
                    hrSamples: state.heartRateSamples,
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

            case let .scoreComputed(score, _):
                state.currentScore = score
                return .none

            case let .triggerDetected(event):
                state.triggerEvent = event
                state.lastTriggerTime = event.timestamp
                state.monitoringState = .triggered

                guard let targetWakeTime = state.targetWakeTime else {
                    return .merge(
                        .cancel(id: CancelID.algorithmTimer),
                        .cancel(id: CancelID.heartRateStream),
                        .cancel(id: CancelID.motionStream)
                    )
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
                    .cancel(id: CancelID.heartRateStream),
                    .cancel(id: CancelID.motionStream),
                    .run { [motionClient] _ in await motionClient.stopUpdates() },
                    .run { send in
                        await send(.alarmFiredSent(Result {
                            let envelope = Envelope(type: .alarmFired, payload: payload)
                            let message = try TransportMessage(envelope: envelope)
                            try wcSessionClient.updateContext(message)
                        }))
                    }
                )

            case .alarmFiredSent(.success):
                return .none

            case let .alarmFiredSent(.failure(error)):
                print("[MonitoringFeature] alarmFired 전송 실패: \(error.localizedDescription)")
                return .none
            }
        }
    }
}

// MARK: - Sensitivity → Threshold

private func sensitivityThreshold(_ sensitivity: AlarmSchedule.Sensitivity) -> Double {
    switch sensitivity {
    case .conservative: return 0.80
    case .balanced:     return 0.72
    case .sensitive:    return 0.60
    }
}
