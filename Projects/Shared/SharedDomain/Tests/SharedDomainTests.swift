import XCTest
@testable import SharedDomain

final class SharedDomainTests: XCTestCase {
    func testAlarmScheduleCreation() {
        let schedule = AlarmSchedule(
            wakeTimeLocal: "07:30",
            windowMinutes: 30,
            sensitivity: .balanced,
            enabled: true
        )

        XCTAssertEqual(schedule.wakeTimeLocal, "07:30")
        XCTAssertEqual(schedule.windowMinutes, 30)
        XCTAssertEqual(schedule.sensitivity, .balanced)
        XCTAssertTrue(schedule.enabled)
    }
}
