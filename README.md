# JingRanJiTimeInput

一个面向 SwiftUI 的 iOS 时间输入控件：保留 `UIPickerView` 的滚动惯性，同时让系统数字键盘与小时/分钟滚轮双向同步。

## 特性

- 默认完整时间输入：按键按“分钟优先、右对齐”填充，例如 `1 -> 00:01`、`1305 -> 13:05`。
- 点击小时或分钟列，单独控制该列；再次点击当前列，返回完整时间控制。
- 拖动滚轮时自动收起键盘；首次轻点滚轮仅唤醒键盘，避免误切换控制列。
- 小时和分钟循环，数值始终保持在 `00:00...23:59`。
- 自定义不透明选中条，使用公开 UIKit API，不依赖 `UIPickerView` 私有子视图。
- 内置井然记暖色/曜石黑样式，也支持使用宿主 App 的系统 tint 色。

## 安装

在 Xcode 中选择 **File > Add Package Dependencies**，输入：

```
https://github.com/Henry-Z-Morgan/JingRanJiTimeInput.git
```

## 使用

```swift
import SwiftUI
import JingRanJiTimeInput

struct BookingTimeView: View {
    @State private var startTime = TimeInput(hour: 9, minute: 0)!

    var body: some View {
        TimeInputPicker(time: $startTime, style: .jingRanJi)
    }
}
```

若希望采用宿主 App 的系统 tint 色：

```swift
TimeInputPicker(time: $startTime, style: .system)
```

## 要求

- iOS 16+
- Swift 5.10+
- 无第三方依赖

## 许可证

MIT。
