# JingRanJiTimeInput

一个面向 SwiftUI 的 iOS 时间输入控件：保留 `UIPickerView` 的滚动惯性，同时让系统数字键盘与小时/分钟滚轮双向同步。

包名源自项目来源；库源码不包含任何品牌色、业务文案或产品预设。

## 特性

- 默认完整时间输入：按键按“分钟优先、右对齐”填充，例如 `1 -> 00:01`、`1305 -> 13:05`。
- 点击小时或分钟列，单独控制该列；再次点击当前列，返回完整时间控制。
- 小时和分钟循环，数值始终保持在 `00:00...23:59`。
- 使用公开 UIKit API 绘制不透明选中条，不依赖 `UIPickerView` 私有子视图。
- 外观、键盘/滚轮行为和状态回调均由宿主 App 配置。

## 安装

在 Xcode 中选择 **File > Add Package Dependencies**，输入：

```text
https://github.com/Henry-Z-Morgan/JingRanJiTimeInput.git
```

发布版本后，推荐使用 **Up to Next Major Version** 规则锁定首个稳定版本；开发期可临时选择 `main`。

## 最小使用

```swift
import SwiftUI
import JingRanJiTimeInput

struct BookingTimeView: View {
    @State private var startTime = TimeInput(hour: 9, minute: 0)!

    var body: some View {
        TimeInputPicker(time: $startTime)
    }
}
```

默认外观是中性的系统语义色：

```swift
TimeInputPickerAppearance.default
```

## 自定义外观

```swift
let appearance = TimeInputPickerAppearance(
    selectedTextColor: .systemOrange,
    unselectedTextColor: .secondaryLabel,
    selectionMaskColor: .systemBackground,
    selectionBackgroundColor: .secondarySystemFill,
    wheelFont: .monospacedDigitSystemFont(ofSize: 22, weight: .regular),
    selectedFont: .monospacedDigitSystemFont(ofSize: 22, weight: .medium),
    rowHeight: 30,
    selectionBarHeight: 30,
    selectionBarCornerRadius: 12,
    selectionHorizontalInset: 0.08
)
```

可配置项包括：普通/选中数字颜色、选中条遮罩色与背景色、普通/选中字体、滚轮行高、选中条高度/圆角，以及左右留白比例。

## 自定义交互与回调

```swift
TimeInputPicker(
    time: $startTime,
    appearance: appearance,
    behavior: TimeInputPickerBehavior(
        opensKeyboardOnAppear: true,
        dismissesKeyboardOnWheelDrag: true,
        restoresKeyboardOnWheelTap: true,
        initialControlMode: .fullTime
    ),
    wheelHeight: 180,
    onTimeChange: { time in
        print(time.formatted)
    },
    onControlModeChange: { mode in
        print(mode)
    }
)
```

`TimeInputControlMode` 支持 `.fullTime`、`.hour`、`.minute`。宿主 App 可基于该回调自行更新提示文案、埋点或其他界面状态。

## Showcase

见 [Examples/TimeInputShowcase](Examples/TimeInputShowcase)。它展示中性默认样式、颜色替换、字体与行高、选中条规格，以及键盘/滚轮行为配置；不属于库产物。

## 要求

- iOS 16+
- Swift 5.10+
- 无第三方依赖

## 许可证

MIT。
