import Foundation
import SharedDomain

// MARK: - Date Encoding Strategy
// Date는 ISO8601 형식으로 인코딩/디코딩 (예: "2026-01-19T12:34:56Z")
// - 가독성이 높아 디버깅에 유리
// - 표준 형식으로 플랫폼 간 호환성 보장
public extension JSONEncoder {
    static var transportEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var transportDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

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
    case ping = "ping"
    case sessionState = "session_state"
    case alarmFired = "alarm_fired"
    case sessionSummary = "session_summary"
    case error = "error"
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

public struct PingPayload: Codable, Sendable {
    public let timestamp: Date

    public init(timestamp: Date = Date()) {
        self.timestamp = timestamp
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
