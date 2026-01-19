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
}
