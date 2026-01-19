import Foundation

// MARK: - AlarmSchedule
public struct AlarmSchedule: Codable, Equatable, Sendable {
    public let wakeTimeLocal: String // "HH:mm" format
    public let windowMinutes: Int
    public let sensitivity: Sensitivity
    public let enabled: Bool

    public init(
        wakeTimeLocal: String,
        windowMinutes: Int,
        sensitivity: Sensitivity,
        enabled: Bool
    ) {
        self.wakeTimeLocal = wakeTimeLocal
        self.windowMinutes = windowMinutes
        self.sensitivity = sensitivity
        self.enabled = enabled
    }

    public enum Sensitivity: String, Codable, Sendable {
        case balanced
        case sensitive
        case conservative
    }
}

// MARK: - WakeabilityScore
public struct WakeabilityScore: Codable, Equatable, Sendable {
    public let score: Double
    public let components: Components

    public init(score: Double, components: Components) {
        self.score = score
        self.components = components
    }

    public struct Components: Codable, Equatable, Sendable {
        public let motionScore: Double
        public let heartRateScore: Double

        public init(motionScore: Double, heartRateScore: Double) {
            self.motionScore = motionScore
            self.heartRateScore = heartRateScore
        }
    }
}

// MARK: - Sensor Samples
public struct MotionSample: Equatable, Sendable {
    public let timestamp: Date
    public let magnitude: Double // |a| acceleration magnitude

    public init(timestamp: Date, magnitude: Double) {
        self.timestamp = timestamp
        self.magnitude = magnitude
    }
}

public struct HeartRateSample: Equatable, Sendable {
    public let timestamp: Date
    public let bpm: Double

    public init(timestamp: Date, bpm: Double) {
        self.timestamp = timestamp
        self.bpm = bpm
    }
}

// MARK: - Algorithm Output Events
public struct ScoreUpdate: Equatable, Sendable {
    public let score: Double
    public let components: WakeabilityScore.Components
    public let timestamp: Date

    public init(score: Double, components: WakeabilityScore.Components, timestamp: Date) {
        self.score = score
        self.components = components
        self.timestamp = timestamp
    }
}

public struct TriggerEvent: Equatable, Sendable {
    public let reason: TriggerReason
    public let timestamp: Date
    public let score: Double
    public let components: WakeabilityScore.Components

    public init(reason: TriggerReason, timestamp: Date, score: Double, components: WakeabilityScore.Components) {
        self.reason = reason
        self.timestamp = timestamp
        self.score = score
        self.components = components
    }

    public enum TriggerReason: String, Equatable, Sendable {
        case smart = "SMART_SCORE"
        case forced = "FORCED_TIME"
    }
}

// MARK: - WakeSessionSummary
public struct WakeSessionSummary: Codable, Equatable, Sendable {
    public let windowStartAt: Date
    public let windowEndAt: Date
    public let firedAt: Date
    public let reason: FiredReason
    public let scoreAtFire: Double
    public let bestCandidateAt: Date?
    public let bestScore: Double?
    public let batteryImpactEstimate: Int?

    public init(
        windowStartAt: Date,
        windowEndAt: Date,
        firedAt: Date,
        reason: FiredReason,
        scoreAtFire: Double,
        bestCandidateAt: Date? = nil,
        bestScore: Double? = nil,
        batteryImpactEstimate: Int? = nil
    ) {
        self.windowStartAt = windowStartAt
        self.windowEndAt = windowEndAt
        self.firedAt = firedAt
        self.reason = reason
        self.scoreAtFire = scoreAtFire
        self.bestCandidateAt = bestCandidateAt
        self.bestScore = bestScore
        self.batteryImpactEstimate = batteryImpactEstimate
    }

    public enum FiredReason: String, Codable, Sendable {
        case smart = "SMART"
        case forced = "FORCED"
    }
}
