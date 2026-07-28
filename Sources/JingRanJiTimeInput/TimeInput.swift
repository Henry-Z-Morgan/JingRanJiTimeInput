import Foundation

/// 一个合法的 24 小时时间值。
public struct TimeInput: Equatable, Sendable {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
