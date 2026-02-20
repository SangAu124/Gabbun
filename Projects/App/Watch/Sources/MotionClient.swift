import Foundation
import CoreMotion
import ComposableArchitecture
import SharedDomain

// MARK: - MotionClient

@DependencyClient
public struct MotionClient: Sendable {
    public var startUpdates: @Sendable () async throws -> Void = { }
    public var stopUpdates: @Sendable () async -> Void = { }
    public var motionSamples: @Sendable () -> AsyncStream<MotionSample> = { .finished }
}

// MARK: - DependencyKey

extension MotionClient: DependencyKey {
    public static let liveValue: MotionClient = {
        let actor = MotionActor()
        return MotionClient(
            startUpdates: { try await actor.startUpdates() },
            stopUpdates: { await actor.stopUpdates() },
            motionSamples: { actor.makeStream() }
        )
    }()

    public static let testValue = MotionClient()
}

extension DependencyValues {
    public var motionClient: MotionClient {
        get { self[MotionClient.self] }
        set { self[MotionClient.self] = newValue }
    }
}

// MARK: - MotionActor (thread-safe implementation)

private actor MotionActor {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var continuation: AsyncStream<MotionSample>.Continuation?

    // 25Hz 샘플링
    private static let updateInterval: TimeInterval = 1.0 / 25.0

    // MARK: - Updates

    func startUpdates() throws {
        guard motionManager.isAccelerometerAvailable else {
            throw MotionClientError.accelerometerUnavailable
        }

        stopUpdatesSync()

        motionManager.accelerometerUpdateInterval = Self.updateInterval
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
            guard let self, let data else { return }
            let magnitude = sqrt(
                data.acceleration.x * data.acceleration.x +
                data.acceleration.y * data.acceleration.y +
                data.acceleration.z * data.acceleration.z
            )
            let sample = MotionSample(timestamp: Date(), magnitude: magnitude)
            Task { await self.yield(sample) }
        }
    }

    func stopUpdates() {
        stopUpdatesSync()
    }

    private func stopUpdatesSync() {
        motionManager.stopAccelerometerUpdates()
        continuation?.finish()
        continuation = nil
    }

    private func yield(_ sample: MotionSample) {
        continuation?.yield(sample)
    }

    // MARK: - Stream

    func makeStream() -> AsyncStream<MotionSample> {
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

// MARK: - Errors

private enum MotionClientError: Error {
    case accelerometerUnavailable
}
