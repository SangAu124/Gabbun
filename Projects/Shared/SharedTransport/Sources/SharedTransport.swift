import Foundation
import SharedDomain

// MARK: - Envelope
public struct Envelope<T: Codable>: Codable, Sendable where T: Sendable {
    public let schemaVersion: Int
    public let messageId: UUID
    public let sentAt: Date
    public let type: MessageType
    public let payload: T

    public init(
        schemaVersion: Int = 1,
        messageId: UUID = UUID(),
        sentAt: Date = Date(),
        type: MessageType,
        payload: T
    ) {
        self.schemaVersion = schemaVersion
        self.messageId = messageId
        self.sentAt = sentAt
        self.type = type
        self.payload = payload
    }
}

// MARK: - MessageType
public enum MessageType: String, Codable, Sendable {
    case updateSchedule = "update_schedule"
    case cancelSchedule = "cancel_schedule"
    case alarmFired = "alarm_fired"
    case sessionSummary = "session_summary"
    case error = "error"
    case sessionState = "session_state"
}

// MARK: - iPhone → Watch Payloads
public struct UpdateSchedulePayload: Codable, Sendable {
    public let schedule: AlarmSchedule
    public let effectiveDate: String // "YYYY-MM-DD"

    public init(schedule: AlarmSchedule, effectiveDate: String) {
        self.schedule = schedule
        self.effectiveDate = effectiveDate
    }
}

public struct CancelSchedulePayload: Codable, Sendable {
    public let effectiveDate: String

    public init(effectiveDate: String) {
        self.effectiveDate = effectiveDate
    }
}

// MARK: - Watch → iPhone Payloads
public struct AlarmFiredEventPayload: Codable, Sendable {
    public let targetWakeAt: Date
    public let firedAt: Date
    public let reason: WakeSessionSummary.FiredReason
    public let scoreAtFire: Double
    public let components: WakeabilityScore.Components
    public let cooldownApplied: Bool

    public init(
        targetWakeAt: Date,
        firedAt: Date,
        reason: WakeSessionSummary.FiredReason,
        scoreAtFire: Double,
        components: WakeabilityScore.Components,
        cooldownApplied: Bool
    ) {
        self.targetWakeAt = targetWakeAt
        self.firedAt = firedAt
        self.reason = reason
        self.scoreAtFire = scoreAtFire
        self.components = components
        self.cooldownApplied = cooldownApplied
    }
}

public struct SessionSummaryPayload: Codable, Sendable {
    public let summary: WakeSessionSummary

    public init(summary: WakeSessionSummary) {
        self.summary = summary
    }
}

public struct ErrorPayload: Codable, Sendable {
    public let code: String
    public let detail: String

    public init(code: String, detail: String) {
        self.code = code
        self.detail = detail
    }
}

public struct SessionStatePayload: Codable, Sendable {
    public let state: String
    public let lastScore: Double?

    public init(state: String, lastScore: Double? = nil) {
        self.state = state
        self.lastScore = lastScore
    }
}
