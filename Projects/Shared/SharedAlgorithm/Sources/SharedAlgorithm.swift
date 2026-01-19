import Foundation
import SharedDomain

// MARK: - FeatureExtraction
public struct FeatureExtractor: Sendable {
    public init() {}

    public func extractMotionFeature(accelerationData: [Double]) -> Double {
        // Placeholder: 실제로는 움직임 변화량 계산
        guard !accelerationData.isEmpty else { return 0.0 }
        let sum = accelerationData.reduce(0.0, +)
        return sum / Double(accelerationData.count)
    }

    public func extractHeartRateFeature(heartRateData: [Double]) -> Double {
        // Placeholder: 실제로는 심박수 변화율 계산
        guard !heartRateData.isEmpty else { return 0.0 }
        let sum = heartRateData.reduce(0.0, +)
        return sum / Double(heartRateData.count)
    }
}

// MARK: - ScoreCalculator
public struct ScoreCalculator: Sendable {
    public init() {}

    public func calculateWakeability(
        motionFeature: Double,
        heartRateFeature: Double
    ) -> WakeabilityScore {
        let motionScore = normalize(motionFeature, min: 0.0, max: 10.0)
        let heartRateScore = normalize(heartRateFeature, min: 60.0, max: 100.0)

        let combinedScore = (motionScore * 0.6) + (heartRateScore * 0.4)

        return WakeabilityScore(
            score: combinedScore,
            components: WakeabilityScore.Components(
                motionScore: motionScore,
                heartRateScore: heartRateScore
            )
        )
    }

    private func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0.0 }
        let clamped = Swift.max(min, Swift.min(max, value))
        return (clamped - min) / (max - min)
    }
}

// MARK: - TriggerStateMachine
public enum TriggerState: Sendable {
    case idle
    case monitoring
    case triggered
    case forced
}

public struct TriggerStateMachine: Sendable {
    public let threshold: Double
    public let cooldownSeconds: Int

    public init(threshold: Double = 0.7, cooldownSeconds: Int = 120) {
        self.threshold = threshold
        self.cooldownSeconds = cooldownSeconds
    }

    public func shouldTrigger(score: Double, lastTriggerTime: Date?) -> Bool {
        guard score >= threshold else { return false }

        if let lastTime = lastTriggerTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            return elapsed >= Double(cooldownSeconds)
        }

        return true
    }

    public func shouldForceTrigger(currentTime: Date, targetTime: Date) -> Bool {
        return currentTime >= targetTime
    }
}
