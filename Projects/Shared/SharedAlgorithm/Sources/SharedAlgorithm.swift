import Foundation
import SharedDomain

// MARK: - Motion Features

/// Motion Feature 추출 (60초 윈도우)
public struct MotionFeatures: Equatable, Sendable {
    public let std: Double         // 표준편차 (움직임 격렬함)
    public let peaks: Int          // 임계값 초과 피크 수
    public let energy: Double      // Σ |a|^2

    public init(std: Double, peaks: Int, energy: Double) {
        self.std = std
        self.peaks = peaks
        self.energy = energy
    }
}

public struct MotionFeatureExtractor: Sendable {
    private let windowSeconds: TimeInterval
    private let peakThreshold: Double

    public init(windowSeconds: TimeInterval = 60.0, peakThreshold: Double = 1.5) {
        self.windowSeconds = windowSeconds
        self.peakThreshold = peakThreshold
    }

    public func extract(from samples: [MotionSample], at currentTime: Date) -> MotionFeatures {
        let cutoffTime = currentTime.addingTimeInterval(-windowSeconds)
        let windowSamples = samples.filter { $0.timestamp >= cutoffTime && $0.timestamp <= currentTime }

        guard !windowSamples.isEmpty else {
            return MotionFeatures(std: 0.0, peaks: 0, energy: 0.0)
        }

        let magnitudes = windowSamples.map { $0.magnitude }

        // std
        let mean = magnitudes.reduce(0.0, +) / Double(magnitudes.count)
        let variance = magnitudes.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(magnitudes.count)
        let std = sqrt(variance)

        // peaks
        let peaks = magnitudes.filter { $0 > peakThreshold }.count

        // energy
        let energy = magnitudes.map { $0 * $0 }.reduce(0.0, +)

        return MotionFeatures(std: std, peaks: peaks, energy: energy)
    }
}

// MARK: - HeartRate Features

/// HeartRate Feature 추출 (120초 윈도우)
public struct HeartRateFeatures: Equatable, Sendable {
    public let mean: Double        // 평균 HR
    public let slope: Double       // 기울기 (최근 30초 평균 - 이전 90초 평균)
    public let variance: Double    // 분산

    public init(mean: Double, slope: Double, variance: Double) {
        self.mean = mean
        self.slope = slope
        self.variance = variance
    }
}

public struct HeartRateFeatureExtractor: Sendable {
    private let windowSeconds: TimeInterval
    private let recentSeconds: TimeInterval

    public init(windowSeconds: TimeInterval = 120.0, recentSeconds: TimeInterval = 30.0) {
        self.windowSeconds = windowSeconds
        self.recentSeconds = recentSeconds
    }

    public func extract(from samples: [HeartRateSample], at currentTime: Date) -> HeartRateFeatures {
        let cutoffTime = currentTime.addingTimeInterval(-windowSeconds)
        let windowSamples = samples.filter { $0.timestamp >= cutoffTime && $0.timestamp <= currentTime }

        guard !windowSamples.isEmpty else {
            return HeartRateFeatures(mean: 0.0, slope: 0.0, variance: 0.0)
        }

        let bpms = windowSamples.map { $0.bpm }

        // mean
        let mean = bpms.reduce(0.0, +) / Double(bpms.count)

        // slope (최근 30초 평균 - 이전 90초 평균)
        let recentCutoff = currentTime.addingTimeInterval(-recentSeconds)
        let recentSamples = windowSamples.filter { $0.timestamp >= recentCutoff }
        let olderSamples = windowSamples.filter { $0.timestamp < recentCutoff }

        let recentMean = recentSamples.isEmpty ? 0.0 : recentSamples.map { $0.bpm }.reduce(0.0, +) / Double(recentSamples.count)
        let olderMean = olderSamples.isEmpty ? 0.0 : olderSamples.map { $0.bpm }.reduce(0.0, +) / Double(olderSamples.count)
        let slope = recentMean - olderMean

        // variance
        let variance = bpms.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(bpms.count)

        return HeartRateFeatures(mean: mean, slope: slope, variance: variance)
    }
}

// MARK: - Wakeability Score Calculator

public struct WakeabilityConfig: Sendable {
    public let motionWeight: Double
    public let heartRateWeight: Double
    public let stillnessWeight: Double
    public let motionPeakAlpha: Double
    public let motionEnergyBeta: Double
    public let hrSlopeGamma: Double
    public let hrVarDelta: Double
    public let stillnessThreshold: Double

    public init(
        motionWeight: Double = 0.65,
        heartRateWeight: Double = 0.35,
        stillnessWeight: Double = 0.1,
        motionPeakAlpha: Double = 0.3,
        motionEnergyBeta: Double = 0.2,
        hrSlopeGamma: Double = 0.6,
        hrVarDelta: Double = 0.4,
        stillnessThreshold: Double = 0.1
    ) {
        self.motionWeight = motionWeight
        self.heartRateWeight = heartRateWeight
        self.stillnessWeight = stillnessWeight
        self.motionPeakAlpha = motionPeakAlpha
        self.motionEnergyBeta = motionEnergyBeta
        self.hrSlopeGamma = hrSlopeGamma
        self.hrVarDelta = hrVarDelta
        self.stillnessThreshold = stillnessThreshold
    }
}

public struct WakeabilityScoreCalculator: Sendable {
    private let config: WakeabilityConfig

    public init(config: WakeabilityConfig = WakeabilityConfig()) {
        self.config = config
    }

    public func calculate(motion: MotionFeatures, heartRate: HeartRateFeatures) -> WakeabilityScore {
        // Motion 정규화 (0~1)
        let motionStdNorm = normalize(motion.std, min: 0.0, max: 2.0)
        let motionPeaksNorm = normalize(Double(motion.peaks), min: 0.0, max: 20.0)
        let motionEnergyNorm = normalize(motion.energy, min: 0.0, max: 100.0)

        let motionCombined = motionStdNorm + config.motionPeakAlpha * motionPeaksNorm + config.motionEnergyBeta * motionEnergyNorm
        let motionScore = clamp(motionCombined / (1.0 + config.motionPeakAlpha + config.motionEnergyBeta), min: 0.0, max: 1.0)

        // HeartRate 정규화 (0~1)
        let hrSlopeNorm = normalize(heartRate.slope, min: -10.0, max: 10.0)
        let hrVarNorm = normalize(heartRate.variance, min: 0.0, max: 100.0)

        let hrCombined = config.hrSlopeGamma * hrSlopeNorm + config.hrVarDelta * hrVarNorm
        let heartRateScore = clamp(hrCombined / (config.hrSlopeGamma + config.hrVarDelta), min: 0.0, max: 1.0)

        // Stillness penalty (모션이 거의 없으면 패널티)
        let stillnessPenalty = motionScore < config.stillnessThreshold ? config.stillnessWeight : 0.0

        // 최종 점수
        let finalScore = config.motionWeight * motionScore + config.heartRateWeight * heartRateScore - stillnessPenalty
        let clampedScore = clamp(finalScore, min: 0.0, max: 1.0)

        return WakeabilityScore(
            score: clampedScore,
            components: WakeabilityScore.Components(
                motionScore: motionScore,
                heartRateScore: heartRateScore
            )
        )
    }

    private func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0.0 }
        let clamped = clamp(value, min: min, max: max)
        return (clamped - min) / (max - min)
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }
}

// MARK: - Trigger Decider

public struct TriggerDecider: Sendable {
    private let threshold: Double
    private let cooldownSeconds: TimeInterval
    private let majorityCount: Int
    private let majorityWindow: Int

    public init(
        threshold: Double = 0.72,
        cooldownSeconds: TimeInterval = 300.0, // 5분
        majorityCount: Int = 2,
        majorityWindow: Int = 3
    ) {
        self.threshold = threshold
        self.cooldownSeconds = cooldownSeconds
        self.majorityCount = majorityCount
        self.majorityWindow = majorityWindow
    }

    /// 최근 스코어 기록에서 트리거 여부 판단
    /// - Parameters:
    ///   - recentScores: 최근 스코어 배열 (시간순)
    ///   - lastTriggerTime: 마지막 트리거 시각
    ///   - currentTime: 현재 시각
    /// - Returns: 트리거 여부
    public func shouldTriggerSmart(
        recentScores: [ScoreUpdate],
        lastTriggerTime: Date?,
        currentTime: Date
    ) -> Bool {
        // Cooldown check
        if let lastTime = lastTriggerTime {
            let elapsed = currentTime.timeIntervalSince(lastTime)
            if elapsed < cooldownSeconds {
                return false
            }
        }

        // Majority check (최근 3개 중 2개 이상 threshold 초과)
        let lastN = Array(recentScores.suffix(majorityWindow))
        let overThresholdCount = lastN.filter { $0.score >= threshold }.count

        return overThresholdCount >= majorityCount
    }

    /// Forced 트리거 여부 (목표 시각 도달)
    public func shouldTriggerForced(currentTime: Date, wakeTime: Date) -> Bool {
        return currentTime >= wakeTime
    }
}

// MARK: - Wakeability Algorithm (통합)

public struct WakeabilityAlgorithm: Sendable {
    private let motionExtractor: MotionFeatureExtractor
    private let hrExtractor: HeartRateFeatureExtractor
    private let scoreCalculator: WakeabilityScoreCalculator
    private let triggerDecider: TriggerDecider

    public init(
        motionExtractor: MotionFeatureExtractor = MotionFeatureExtractor(),
        hrExtractor: HeartRateFeatureExtractor = HeartRateFeatureExtractor(),
        scoreCalculator: WakeabilityScoreCalculator = WakeabilityScoreCalculator(),
        triggerDecider: TriggerDecider = TriggerDecider()
    ) {
        self.motionExtractor = motionExtractor
        self.hrExtractor = hrExtractor
        self.scoreCalculator = scoreCalculator
        self.triggerDecider = triggerDecider
    }

    /// 30초 tick마다 호출
    /// - Parameters:
    ///   - motionSamples: 누적된 모션 샘플
    ///   - hrSamples: 누적된 심박 샘플
    ///   - currentTime: 현재 시각
    /// - Returns: 현재 Wakeability Score
    public func computeScore(
        motionSamples: [MotionSample],
        hrSamples: [HeartRateSample],
        currentTime: Date
    ) -> WakeabilityScore {
        let motionFeatures = motionExtractor.extract(from: motionSamples, at: currentTime)
        let hrFeatures = hrExtractor.extract(from: hrSamples, at: currentTime)
        return scoreCalculator.calculate(motion: motionFeatures, heartRate: hrFeatures)
    }

    /// 트리거 판단
    /// - Parameters:
    ///   - recentScores: 최근 스코어 기록
    ///   - lastTriggerTime: 마지막 트리거 시각
    ///   - currentTime: 현재 시각
    ///   - wakeTime: 목표 기상 시각
    /// - Returns: TriggerEvent (트리거되지 않으면 nil)
    public func evaluateTrigger(
        recentScores: [ScoreUpdate],
        lastTriggerTime: Date?,
        currentTime: Date,
        wakeTime: Date
    ) -> TriggerEvent? {
        // Forced 트리거 우선
        if triggerDecider.shouldTriggerForced(currentTime: currentTime, wakeTime: wakeTime) {
            let latestScore = recentScores.last ?? ScoreUpdate(
                score: 0.0,
                components: WakeabilityScore.Components(motionScore: 0.0, heartRateScore: 0.0),
                timestamp: currentTime
            )
            return TriggerEvent(
                reason: .forced,
                timestamp: currentTime,
                score: latestScore.score,
                components: latestScore.components
            )
        }

        // Smart 트리거
        if triggerDecider.shouldTriggerSmart(
            recentScores: recentScores,
            lastTriggerTime: lastTriggerTime,
            currentTime: currentTime
        ) {
            guard let latestScore = recentScores.last else { return nil }
            return TriggerEvent(
                reason: .smart,
                timestamp: currentTime,
                score: latestScore.score,
                components: latestScore.components
            )
        }

        return nil
    }
}
