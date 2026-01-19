import XCTest
@testable import SharedTransport
@testable import SharedDomain

final class SharedTransportTests: XCTestCase {
    func testEnvelopeCreation() throws {
        let payload = UpdateSchedulePayload(
            schedule: AlarmSchedule(
                wakeTimeLocal: "07:30",
                windowMinutes: 30,
                sensitivity: .balanced,
                enabled: true
            ),
            effectiveDate: "2026-01-20"
        )

        let envelope = Envelope(
            type: .updateSchedule,
            payload: payload
        )

        XCTAssertEqual(envelope.schemaVersion, 1)
        XCTAssertEqual(envelope.type, .updateSchedule)
        XCTAssertEqual(envelope.payload.effectiveDate, "2026-01-20")
    }

    // MARK: - Encode/Decode Roundtrip Tests

    func testUpdateScheduleEncodeDecode() throws {
        // Given
        let originalPayload = UpdateSchedulePayload(
            schedule: AlarmSchedule(
                wakeTimeLocal: "07:30",
                windowMinutes: 30,
                sensitivity: .balanced,
                enabled: true
            ),
            effectiveDate: "2026-01-20"
        )

        let originalEnvelope = Envelope(
            schemaVersion: 1,
            messageId: UUID(),
            sentAt: Date(),
            type: .updateSchedule,
            payload: originalPayload
        )

        // When: Encode
        let encoded = try JSONEncoder.transportEncoder.encode(originalEnvelope)

        // Then: Decode
        let decoded = try JSONDecoder.transportDecoder.decode(
            Envelope<UpdateSchedulePayload>.self,
            from: encoded
        )

        // Verify
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.type, .updateSchedule)
        XCTAssertEqual(decoded.messageId, originalEnvelope.messageId)
        XCTAssertEqual(decoded.payload.schedule.wakeTimeLocal, "07:30")
        XCTAssertEqual(decoded.payload.schedule.windowMinutes, 30)
        XCTAssertEqual(decoded.payload.schedule.sensitivity, .balanced)
        XCTAssertEqual(decoded.payload.schedule.enabled, true)
        XCTAssertEqual(decoded.payload.effectiveDate, "2026-01-20")

        // Date는 ISO8601 인코딩으로 인해 밀리초 제거됨 (1초 정밀도)
        XCTAssertEqual(
            decoded.sentAt.timeIntervalSince1970,
            originalEnvelope.sentAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testSessionSummaryEncodeDecode() throws {
        // Given
        let now = Date()
        let summary = WakeSessionSummary(
            windowStartAt: now.addingTimeInterval(-1800),
            windowEndAt: now,
            firedAt: now.addingTimeInterval(-600),
            reason: .smart,
            scoreAtFire: 0.85,
            bestCandidateAt: now.addingTimeInterval(-900),
            bestScore: 0.92,
            batteryImpactEstimate: 15
        )

        let originalPayload = SessionSummaryPayload(summary: summary)
        let originalEnvelope = Envelope(
            type: .sessionSummary,
            payload: originalPayload
        )

        // When: Encode
        let encoded = try JSONEncoder.transportEncoder.encode(originalEnvelope)

        // Then: Decode
        let decoded = try JSONDecoder.transportDecoder.decode(
            Envelope<SessionSummaryPayload>.self,
            from: encoded
        )

        // Verify
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.type, .sessionSummary)
        XCTAssertEqual(decoded.payload.summary.reason, .smart)
        XCTAssertEqual(decoded.payload.summary.scoreAtFire, 0.85)
        XCTAssertEqual(decoded.payload.summary.bestScore, 0.92)
        XCTAssertEqual(decoded.payload.summary.batteryImpactEstimate, 15)

        // Date 필드 검증 (ISO8601은 밀리초 제거, 1초 정밀도)
        XCTAssertEqual(
            decoded.payload.summary.windowStartAt.timeIntervalSince1970,
            summary.windowStartAt.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertEqual(
            decoded.payload.summary.firedAt.timeIntervalSince1970,
            summary.firedAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testPingEncodeDecode() throws {
        // Given
        let originalPayload = PingPayload(timestamp: Date())
        let originalEnvelope = Envelope(
            type: .ping,
            payload: originalPayload
        )

        // When: Encode
        let encoded = try JSONEncoder.transportEncoder.encode(originalEnvelope)

        // Then: Decode
        let decoded = try JSONDecoder.transportDecoder.decode(
            Envelope<PingPayload>.self,
            from: encoded
        )

        // Verify
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.type, .ping)
        XCTAssertEqual(
            decoded.payload.timestamp.timeIntervalSince1970,
            originalPayload.timestamp.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testDateEncodingIsISO8601() throws {
        // Given
        let payload = PingPayload(timestamp: Date(timeIntervalSince1970: 1737302400)) // 2026-01-19 12:00:00 UTC
        let envelope = Envelope(type: .ping, payload: payload)

        // When
        let encoded = try JSONEncoder.transportEncoder.encode(envelope)
        let jsonString = String(data: encoded, encoding: .utf8)!

        // Then: ISO8601 형식 검증 (YYYY-MM-DDTHH:MM:SSZ 패턴)
        // 예: "timestamp":"2026-01-19T12:00:00Z"
        let iso8601Pattern = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"#
        let regex = try NSRegularExpression(pattern: iso8601Pattern)
        let range = NSRange(jsonString.startIndex..., in: jsonString)
        let matches = regex.matches(in: jsonString, range: range)

        XCTAssertGreaterThan(
            matches.count,
            0,
            "Date should be encoded as ISO8601 format (YYYY-MM-DDTHH:MM:SSZ)"
        )
    }
}
