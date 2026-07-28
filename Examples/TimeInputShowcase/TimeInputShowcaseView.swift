import SwiftUI
import UIKit
import JingRanJiTimeInput

/// 公开配置的可运行示例，不属于 Package 的库产物。
struct TimeInputShowcaseView: View {
    @State private var time = TimeInput(hour: 9, minute: 30)!
    @State private var usesPurpleAccent = true
    @State private var compactSelection = false
    @State private var hidesKeyboardOnDrag = true
    @State private var lastMode: TimeInputControlMode = .fullTime

    private var appearance: TimeInputPickerAppearance {
        TimeInputPickerAppearance(
            selectedTextColor: usesPurpleAccent ? .systemPurple : .systemTeal,
            unselectedTextColor: .secondaryLabel,
            selectionMaskColor: .systemBackground,
            selectionBackgroundColor: .secondarySystemFill,
            wheelFont: .monospacedDigitSystemFont(ofSize: compactSelection ? 21 : 24, weight: .regular),
            selectedFont: .monospacedDigitSystemFont(ofSize: compactSelection ? 21 : 24, weight: .medium),
            rowHeight: compactSelection ? 28 : 34,
            selectionBarHeight: compactSelection ? 28 : 34,
            selectionBarCornerRadius: compactSelection ? 10 : 17,
            selectionHorizontalInset: 0.08
        )
    }

    private var behavior: TimeInputPickerBehavior {
        TimeInputPickerBehavior(
            opensKeyboardOnAppear: true,
            dismissesKeyboardOnWheelDrag: hidesKeyboardOnDrag,
            restoresKeyboardOnWheelTap: true,
            initialControlMode: .fullTime
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("时间") {
                    Text(time.formatted)
                        .font(.system(.title, design: .monospaced))
                    Text("当前控制：\(modeName(lastMode))")
                        .foregroundStyle(.secondary)
                }

                Section("控件") {
                    TimeInputPicker(
                        time: $time,
                        appearance: appearance,
                        behavior: behavior,
                        wheelHeight: compactSelection ? 154 : 180,
                        onControlModeChange: { lastMode = $0 }
                    )
                    .id("\(usesPurpleAccent)-\(compactSelection)-\(hidesKeyboardOnDrag)")
                }

                Section("公开配置") {
                    Toggle("紫色选择文字", isOn: $usesPurpleAccent)
                    Toggle("紧凑选中条", isOn: $compactSelection)
                    Toggle("拖动滚轮收起键盘", isOn: $hidesKeyboardOnDrag)
                }
            }
            .navigationTitle("Time Input Showcase")
        }
    }

    private func modeName(_ mode: TimeInputControlMode) -> String {
        switch mode {
        case .fullTime: "完整时间"
        case .hour: "小时"
        case .minute: "分钟"
        }
    }
}
