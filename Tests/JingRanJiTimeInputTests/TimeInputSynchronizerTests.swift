import XCTest
@testable import JingRanJiTimeInput

final class TimeInputSynchronizerTests: XCTestCase {
    func testFullTimeDigitsFillMinuteFirstFromRight() {
        var value = TimeInputSynchronizer()
        ["1", "3", "0", "5"].forEach { value.insertDigit($0) }
        XCTAssertEqual(value.time.formatted, "13:05")
    }

    func testDeleteMovesDigitsBackAndEventuallyZeroes() {
        var value = TimeInputSynchronizer()
        ["1", "3", "0"].forEach { value.insertDigit($0) }
        value.deleteBackward(); XCTAssertEqual(value.time.formatted, "00:13")
        value.deleteBackward(); XCTAssertEqual(value.time.formatted, "00:01")
        value.deleteBackward(); XCTAssertEqual(value.time.formatted, "00:00")
        value.deleteBackward(); XCTAssertEqual(value.time.formatted, "00:00")
    }

    func testOverflowKeepsLastDigitOfInvalidColumn() {
        var value = TimeInputSynchronizer()
        value.insertDigit("8"); value.insertDigit("8")
        XCTAssertEqual(value.time.formatted, "00:08")
    }

    func testColumnTapTogglesBetweenSingleAndFullControl() {
        var value = TimeInputSynchronizer()
        value.applyColumnTap(.hour, modeBeforeTouch: .fullTime)
        XCTAssertEqual(value.controlMode, .hour)
        value.applyColumnTap(.minute, modeBeforeTouch: .hour)
        XCTAssertEqual(value.controlMode, .minute)
        value.applyColumnTap(.minute, modeBeforeTouch: .minute)
        XCTAssertEqual(value.controlMode, .fullTime)
    }

    func testWheelDragResetsToFullTimeControl() {
        var value = TimeInputSynchronizer(initialTime: TimeInput(hour: 13, minute: 43)!)
        value.selectControlMode(.minute)
        value.beginWheelDrag()
        XCTAssertEqual(value.controlMode, .fullTime)
    }

    func testInitialControlModeCanBeConfigured() {
        let value = TimeInputSynchronizer(
            initialTime: TimeInput(hour: 13, minute: 43)!,
            controlMode: .minute
        )

        XCTAssertEqual(value.time.formatted, "13:43")
        XCTAssertEqual(value.controlMode, .minute)
    }
}
