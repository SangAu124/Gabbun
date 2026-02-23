import Foundation
import HealthKit
import ComposableArchitecture
import SharedDomain

// MARK: - HeartRateClient

@DependencyClient
public struct HeartRateClient: Sendable {
    public var requestAuthorization: @Sendable () async throws -> Void = { }
    public var startWorkoutSession: @Sendable () async throws -> Void = { }
    public var stopWorkoutSession: @Sendable () async throws -> Void = { }
    // async: actor-isolated makeStream()을 올바른 concurrency context에서 호출
    public var heartRateSamples: @Sendable () async -> AsyncStream<HeartRateSample> = { .finished }
}

// MARK: - DependencyKey

extension HeartRateClient: DependencyKey {
    public static let liveValue: HeartRateClient = {
        let actor = HeartRateActor()
        return HeartRateClient(
            requestAuthorization: { try await actor.requestAuthorization() },
            startWorkoutSession: { try await actor.startWorkoutSession() },
            stopWorkoutSession: { await actor.stopWorkoutSession() },
            heartRateSamples: { await actor.makeStream() }
        )
    }()

    public static let testValue = HeartRateClient()
}

extension DependencyValues {
    public var heartRateClient: HeartRateClient {
        get { self[HeartRateClient.self] }
        set { self[HeartRateClient.self] = newValue }
    }
}

// MARK: - HeartRateActor (thread-safe implementation)

private actor HeartRateActor {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var query: HKAnchoredObjectQuery?
    private var continuation: AsyncStream<HeartRateSample>.Continuation?

    private static let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private static let heartRateUnit = HKUnit(from: "count/min")

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToRead: Set<HKObjectType> = [Self.heartRateType]
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    // MARK: - Workout Session

    func startWorkoutSession() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // 권한이 없으면 먼저 요청
        try await requestAuthorization()

        // 기존 세션 종료
        await stopWorkoutSession()

        // 워크아웃 설정 (Other 타입 → 수면 모니터링용)
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor

        // 세션 생성
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )

        self.workoutSession = session
        self.workoutBuilder = builder

        // 세션 시작 (백그라운드 실행 유지)
        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        // 실시간 심박 쿼리 시작
        startHeartRateQuery()
    }

    func stopWorkoutSession() async {
        if let q = query {
            healthStore.stop(q)
        }
        query = nil
        continuation?.finish()
        continuation = nil

        if let builder = workoutBuilder {
            try? await builder.endCollection(at: Date())
            try? await builder.finishWorkout()
        }

        workoutSession?.end()
        workoutSession = nil
        workoutBuilder = nil
    }

    // MARK: - Heart Rate Query

    private func startHeartRateQuery() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        let anchoredQuery = HKAnchoredObjectQuery(
            type: Self.heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            guard let self else { return }
            if let samples = samples as? [HKQuantitySample] {
                Task { await self.processSamples(samples) }
            }
        }

        anchoredQuery.updateHandler = { [weak self] _, samples, _, _, error in
            guard let self else { return }
            if let samples = samples as? [HKQuantitySample] {
                Task { await self.processSamples(samples) }
            }
        }

        self.query = anchoredQuery
        healthStore.execute(anchoredQuery)

        // 백그라운드 딜리버리 활성화
        healthStore.enableBackgroundDelivery(for: Self.heartRateType, frequency: .immediate) { _, _ in }
    }

    private func processSamples(_ samples: [HKQuantitySample]) {
        for sample in samples {
            let bpm = sample.quantity.doubleValue(for: Self.heartRateUnit)
            let hrSample = HeartRateSample(timestamp: sample.startDate, bpm: bpm)
            continuation?.yield(hrSample)
        }
    }

    // MARK: - Stream

    func makeStream() -> AsyncStream<HeartRateSample> {
        // 이전 소비자가 있으면 먼저 종료
        continuation?.finish()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { await self?.clearContinuation() }
            }
            self.continuation = continuation
        }
    }

    private func clearContinuation() {
        continuation = nil
    }
}
