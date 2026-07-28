import Foundation

/// 系统数字键盘当前控制的范围。
public enum TimeInputControlMode: Equatable, Sendable {
    case fullTime
    case hour
    case minute

}

/// 数字键盘与小时/分钟滚轮的纯同步逻辑。
///
/// 完整时间模式是右对齐、分钟优先的数字流：`1 -> 00:01`、`130 -> 01:30`。
public struct TimeInputSynchronizer: Equatable {
    public private(set) var time: TimeInput
    public private(set) var controlMode: TimeInputControlMode
    private var keyboardDigits = ""

    public init(
        initialTime: TimeInput = TimeInput(hour: 9, minute: 0)!,
        controlMode: TimeInputControlMode = .fullTime
    ) {
        time = initialTime
        self.controlMode = controlMode
    }

    public var text: String { time.formatted }

    public mutating func selectControlMode(_ mode: TimeInputControlMode) {
        controlMode = mode
        keyboardDigits = ""
    }

    public mutating func applyColumnTap(_ component: TimeInputControlMode, modeBeforeTouch: TimeInputControlMode) {
        precondition(component != .fullTime, "Only hour or minute can be selected")
        selectControlMode(modeBeforeTouch == component ? .fullTime : component)
    }

    /// 开始滚轮拖动后，下一次键盘唤醒回到完整时间模式。
    public mutating func beginWheelDrag() {
        selectControlMode(.fullTime)
    }

    public mutating func insertDigit(_ digit: Character) {
        guard digit.isNumber else { return }
        let limit = controlMode == .fullTime ? 4 : 2
        keyboardDigits = String((keyboardDigits + String(digit)).suffix(limit))
        time = normalizedTime(for: keyboardDigits)
    }

    /// 空缓冲继续退格会将当前控制范围归零。
    public mutating func deleteBackward() {
        if !keyboardDigits.isEmpty { keyboardDigits.removeLast() }
        time = normalizedTime(for: keyboardDigits)
    }

    public mutating func updateFromPicker(hour: Int, minute: Int) {
        guard let selected = TimeInput(hour: hour, minute: minute) else {
            assertionFailure("Picker selection must stay in valid bounds")
            return
        }
        time = selected
    }

    private func normalizedTime(for digits: String) -> TimeInput {
        switch controlMode {
        case .fullTime:
            let rightAligned = String(digits.suffix(4)).leftPadded(to: 4, with: "0")
            let hour = normalizedColumn(Int(rightAligned.prefix(2)) ?? 0, maximum: 23)
            let minute = normalizedColumn(Int(rightAligned.suffix(2)) ?? 0, maximum: 59)
            return TimeInput(hour: hour, minute: minute)!
        case .hour:
            return TimeInput(hour: normalizedColumn(Int(digits) ?? 0, maximum: 23), minute: time.minute)!
        case .minute:
            return TimeInput(hour: time.hour, minute: normalizedColumn(Int(digits) ?? 0, maximum: 59))!
        }
    }

    private func normalizedColumn(_ value: Int, maximum: Int) -> Int {
        value <= maximum ? value : value % 10
    }
}

private extension String {
    func leftPadded(to length: Int, with padding: Character) -> String {
        String(repeating: String(padding), count: max(0, length - count)) + self
    }
}
