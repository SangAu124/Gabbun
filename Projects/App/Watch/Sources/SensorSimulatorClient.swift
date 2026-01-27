import Foundation
import ComposableArchitecture
import SharedDomain

// MARK: - Sensor Simulation Mode
public enum SensorSimulationMode: String, Equatable, Sendable {
    case deepSleep      // 깊은 수면: 낮은 움직임, 안정적 심박 → 낮은 점수
    case lightSleep     // 얕은 수면: 약간의 움직임, 심박 변동 → 중간 점수
    case awakening      // 각성 중: 높은 움직임, 심박 상승 → 높은 점수 (SMART 트리거 유발)
}

// MARK: - SensorSimulatorClient
@DependencyClient
public struct SensorSimulatorClient: Sendable {
    /// 현재 시뮬레이션 모드에 따른 Motion 샘플 생성 (약 1초 간격, 60개)
    public var generateMotionSamples: @Sendable (SensorSimulationMode, Date) -> [MotionSample] = { _, _ in [] }

    /// 현재 시뮬레이션 모드에 따른 HeartRate 샘플 생성 (약 5초 간격, 24개)
    public var generateHeartRateSamples: @Sendable (SensorSimulationMode, Date) -> [HeartRateSample] = { _, _ in [] }
}

// MARK: - DependencyKey
extension SensorSimulatorClient: DependencyKey {
    public static let liveValue = SensorSimulatorClient(
        generateMotionSamples: { mode, currentTime in
            generateMotionSamplesImpl(mode: mode, currentTime: currentTime)
        },
        generateHeartRateSamples: { mode, currentTime in
            generateHeartRateSamplesImpl(mode: mode, currentTime: currentTime)
        }
    )

    public static let testValue = SensorSimulatorClient()
}

extension DependencyValues {
    public var sensorSimulator: SensorSimulatorClient {
        get { self[SensorSimulatorClient.self] }
        set { self[SensorSimulatorClient.self] = newValue }
    }
}

// MARK: - Implementation

/// Motion 샘플 생성 (60초 윈도우, 약 1초 간격)
private func generateMotionSamplesImpl(mode: SensorSimulationMode, currentTime: Date) -> [MotionSample] {
    let windowSeconds: TimeInterval = 120.0 // 알고리즘 윈도우보다 넉넉하게
    let sampleInterval: TimeInterval = 1.0
    let sampleCount = Int(windowSeconds / sampleInterval)

    var samples: [MotionSample] = []

    for i in 0..<sampleCount {
        let timestamp = currentTime.addingTimeInterval(-windowSeconds + Double(i) * sampleInterval)
        let magnitude = generateMotionMagnitude(mode: mode, index: i)
        samples.append(MotionSample(timestamp: timestamp, magnitude: magnitude))
    }

    return samples
}

/// HeartRate 샘플 생성 (120초 윈도우, 약 5초 간격)
private func generateHeartRateSamplesImpl(mode: SensorSimulationMode, currentTime: Date) -> [HeartRateSample] {
    let windowSeconds: TimeInterval = 150.0 // 알고리즘 윈도우보다 넉넉하게
    let sampleInterval: TimeInterval = 5.0
    let sampleCount = Int(windowSeconds / sampleInterval)

    var samples: [HeartRateSample] = []

    for i in 0..<sampleCount {
        let timestamp = currentTime.addingTimeInterval(-windowSeconds + Double(i) * sampleInterval)
        let bpm = generateHeartRateBpm(mode: mode, index: i, totalCount: sampleCount)
        samples.append(HeartRateSample(timestamp: timestamp, bpm: bpm))
    }

    return samples
}

/// 모드에 따른 가속도 크기 생성
private func generateMotionMagnitude(mode: SensorSimulationMode, index: Int) -> Double {
    // 기본 중력 보정 값 (~1.0) + 노이즈
    let baseGravity = 1.0
    let noise = Double.random(in: -0.05...0.05)

    switch mode {
    case .deepSleep:
        // 깊은 수면: 거의 움직임 없음 (magnitude ≈ 1.0)
        return baseGravity + noise

    case .lightSleep:
        // 얕은 수면: 가끔 작은 움직임 (magnitude ≈ 1.0~1.3)
        let movement = index % 10 == 0 ? Double.random(in: 0.1...0.3) : 0.0
        return baseGravity + movement + noise

    case .awakening:
        // 각성 중: 잦은 큰 움직임 (magnitude ≈ 1.2~2.5)
        // 마지막 30초에 특히 많은 움직임
        let isRecent = index >= 90 // 마지막 30초
        if isRecent {
            let movement = Double.random(in: 0.5...1.5)
            return baseGravity + movement + noise
        } else {
            let movement = index % 5 == 0 ? Double.random(in: 0.3...0.8) : 0.0
            return baseGravity + movement + noise
        }
    }
}

/// 모드에 따른 심박수 생성
private func generateHeartRateBpm(mode: SensorSimulationMode, index: Int, totalCount: Int) -> Double {
    switch mode {
    case .deepSleep:
        // 깊은 수면: 낮고 안정적인 심박 (50~60 bpm)
        return 55.0 + Double.random(in: -5.0...5.0)

    case .lightSleep:
        // 얕은 수면: 약간 높고 약간 변동 (58~68 bpm)
        return 63.0 + Double.random(in: -5.0...5.0)

    case .awakening:
        // 각성 중: 상승 추세 (slope 양수) → 이전 90초 평균 < 최근 30초 평균
        // 전반부: 60~65 bpm, 후반부: 70~80 bpm
        let recentStartIndex = totalCount - 6 // 마지막 30초 (5초 간격 * 6 = 30초)
        if index >= recentStartIndex {
            // 최근 30초: 높은 심박 (slope 상승 유도)
            return 75.0 + Double.random(in: -5.0...5.0)
        } else {
            // 이전 90초: 낮은 심박
            return 58.0 + Double.random(in: -3.0...3.0)
        }
    }
}
