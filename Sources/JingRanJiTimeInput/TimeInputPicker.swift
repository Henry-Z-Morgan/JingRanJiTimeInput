import SwiftUI
import UIKit

/// 时间滚轮的中性外观配置。
///
/// 控件不包含任何产品或品牌预设；宿主 App 可以通过此配置提供自己的设计令牌。
public struct TimeInputPickerAppearance {
    public let selectedTextColor: UIColor
    public let unselectedTextColor: UIColor
    public let selectionMaskColor: UIColor
    public let selectionBackgroundColor: UIColor
    public let wheelFont: UIFont
    public let selectedFont: UIFont
    public let rowHeight: CGFloat
    public let selectionBarHeight: CGFloat
    public let selectionBarCornerRadius: CGFloat
    public let selectionHorizontalInset: CGFloat

    public init(
        selectedTextColor: UIColor = .tintColor,
        unselectedTextColor: UIColor = .secondaryLabel,
        selectionMaskColor: UIColor = .systemBackground,
        selectionBackgroundColor: UIColor = .secondarySystemFill,
        wheelFont: UIFont = .monospacedDigitSystemFont(ofSize: 24, weight: .regular),
        selectedFont: UIFont = .monospacedDigitSystemFont(ofSize: 24, weight: .regular),
        rowHeight: CGFloat = 30,
        selectionBarHeight: CGFloat = 30,
        selectionBarCornerRadius: CGFloat = 15,
        selectionHorizontalInset: CGFloat = 0.08
    ) {
        self.selectedTextColor = selectedTextColor
        self.unselectedTextColor = unselectedTextColor
        self.selectionMaskColor = selectionMaskColor
        self.selectionBackgroundColor = selectionBackgroundColor
        self.wheelFont = wheelFont
        self.selectedFont = selectedFont
        self.rowHeight = rowHeight
        self.selectionBarHeight = selectionBarHeight
        self.selectionBarCornerRadius = selectionBarCornerRadius
        self.selectionHorizontalInset = min(max(selectionHorizontalInset, 0), 0.45)
    }

    /// 使用 Apple 系统语义色的默认外观。
    public static let `default` = TimeInputPickerAppearance()
}

/// 数字键盘与滚轮之间的交互策略。
public struct TimeInputPickerBehavior {
    public let opensKeyboardOnAppear: Bool
    public let dismissesKeyboardOnWheelDrag: Bool
    public let restoresKeyboardOnWheelTap: Bool
    public let initialControlMode: TimeInputControlMode

    public init(
        opensKeyboardOnAppear: Bool = true,
        dismissesKeyboardOnWheelDrag: Bool = true,
        restoresKeyboardOnWheelTap: Bool = true,
        initialControlMode: TimeInputControlMode = .fullTime
    ) {
        self.opensKeyboardOnAppear = opensKeyboardOnAppear
        self.dismissesKeyboardOnWheelDrag = dismissesKeyboardOnWheelDrag
        self.restoresKeyboardOnWheelTap = restoresKeyboardOnWheelTap
        self.initialControlMode = initialControlMode
    }

    public static let `default` = TimeInputPickerBehavior()
}

/// 可直接嵌入 SwiftUI 的时间输入控件。
///
/// 打开时数字键盘控制 `behavior.initialControlMode`（默认完整时间）；拖动滚轮会收起键盘，首次轻点滚轮只唤醒键盘。
public struct TimeInputPicker: View {
    @Binding private var time: TimeInput
    private let appearance: TimeInputPickerAppearance
    private let behavior: TimeInputPickerBehavior
    private let wheelHeight: CGFloat
    private let onTimeChange: (TimeInput) -> Void
    private let onControlModeChange: (TimeInputControlMode) -> Void

    @State private var synchronizer: TimeInputSynchronizer
    @State private var selectionRequestID = 0
    @State private var wantsKeyboard = true
    @State private var awaitsKeyboardWakeAfterWheelDrag = false

    public init(
        time: Binding<TimeInput>,
        appearance: TimeInputPickerAppearance = .default,
        behavior: TimeInputPickerBehavior = .default,
        wheelHeight: CGFloat = 180,
        onTimeChange: @escaping (TimeInput) -> Void = { _ in },
        onControlModeChange: @escaping (TimeInputControlMode) -> Void = { _ in }
    ) {
        _time = time
        self.appearance = appearance
        self.behavior = behavior
        self.wheelHeight = wheelHeight
        self.onTimeChange = onTimeChange
        self.onControlModeChange = onControlModeChange
        _synchronizer = State(initialValue: TimeInputSynchronizer(
            initialTime: time.wrappedValue,
            controlMode: behavior.initialControlMode
        ))
        _wantsKeyboard = State(initialValue: behavior.opensKeyboardOnAppear)
    }

    public var body: some View {
        SystemTimePicker(
            time: Binding(
                get: { synchronizer.time },
                set: { selected in synchronizer.updateFromPicker(hour: selected.hour, minute: selected.minute) }
            ),
            controlMode: synchronizer.controlMode,
            selectionRequestID: selectionRequestID,
            showsSelectionOverlay: wantsKeyboard,
            appearance: appearance,
            onComponentTapped: { component, modeBeforeTouch in
                if awaitsKeyboardWakeAfterWheelDrag {
                    synchronizer.selectControlMode(.fullTime)
                    awaitsKeyboardWakeAfterWheelDrag = false
                } else {
                    synchronizer.applyColumnTap(component, modeBeforeTouch: modeBeforeTouch)
                }
                wantsKeyboard = behavior.restoresKeyboardOnWheelTap
            },
            onWheelDragBegan: {
                synchronizer.beginWheelDrag()
                awaitsKeyboardWakeAfterWheelDrag = behavior.restoresKeyboardOnWheelTap
                if behavior.dismissesKeyboardOnWheelDrag { wantsKeyboard = false }
            }
        )
        .frame(height: wheelHeight)
        .background {
            NumberPadKeyCapture(
                wantsKeyboard: $wantsKeyboard,
                onDigit: { digit in
                    synchronizer.insertDigit(digit)
                    selectionRequestID += 1
                },
                onDelete: {
                    synchronizer.deleteBackward()
                    selectionRequestID += 1
                }
            )
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
        }
        .onChange(of: synchronizer.time) { value in
            if time != value { time = value }
            onTimeChange(value)
        }
        .onChange(of: synchronizer.controlMode) { mode in
            onControlModeChange(mode)
        }
        .onChange(of: time) { value in
            guard synchronizer.time != value else { return }
            synchronizer = TimeInputSynchronizer(initialTime: value, controlMode: synchronizer.controlMode)
            selectionRequestID += 1
        }
    }
}

private struct SystemTimePicker: UIViewRepresentable {
    @Binding var time: TimeInput
    let controlMode: TimeInputControlMode
    let selectionRequestID: Int
    let showsSelectionOverlay: Bool
    let appearance: TimeInputPickerAppearance
    let onComponentTapped: (TimeInputControlMode, TimeInputControlMode) -> Void
    let onWheelDragBegan: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> TimePickerContainerView {
        let container = TimePickerContainerView(appearance: appearance)
        let picker = container.picker
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        picker.selectRow(centeredRow(for: time.hour, component: 0), inComponent: 0, animated: false)
        picker.selectRow(centeredRow(for: time.minute, component: 1), inComponent: 1, animated: false)
        context.coordinator.displayedTime = time
        context.coordinator.displayedControlMode = controlMode
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        picker.addGestureRecognizer(tap)
        context.coordinator.observeWheelPans(in: picker)
        container.selectionOverlay.apply(time: time, controlMode: controlMode, visible: showsSelectionOverlay, animated: false)
        DispatchQueue.main.async { container.alignSelectionOverlayToPickerColumns() }
        return container
    }

    func updateUIView(_ container: TimePickerContainerView, context: Context) {
        let picker = container.picker
        context.coordinator.parent = self
        picker.layoutIfNeeded()
        context.coordinator.observeWheelPans(in: picker)
        container.selectionOverlay.apply(time: time, controlMode: controlMode, visible: showsSelectionOverlay, animated: true)
        DispatchQueue.main.async { container.alignSelectionOverlayToPickerColumns() }

        let timeChanged = context.coordinator.displayedTime != time
        let controlModeChanged = context.coordinator.displayedControlMode != controlMode
        guard timeChanged || controlModeChanged else { return }
        let shouldAnimate = context.coordinator.lastSelectionRequestID != selectionRequestID
        picker.reloadAllComponents()
        picker.selectRow(centeredRow(for: time.hour, component: 0), inComponent: 0, animated: shouldAnimate)
        picker.selectRow(centeredRow(for: time.minute, component: 1), inComponent: 1, animated: shouldAnimate)
        context.coordinator.displayedTime = time
        context.coordinator.displayedControlMode = controlMode
        context.coordinator.lastSelectionRequestID = selectionRequestID
    }

    private func centeredRow(for value: Int, component: Int) -> Int {
        (component == 0 ? 24 : 60) * 100 + value
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate, UIGestureRecognizerDelegate {
        var parent: SystemTimePicker
        var displayedTime: TimeInput?
        var displayedControlMode: TimeInputControlMode?
        var lastSelectionRequestID = 0
        private var observedPanIDs = Set<ObjectIdentifier>()
        private var tappedColumn: TimeInputControlMode?
        private var modeBeforeTap: TimeInputControlMode?
        private var ignoreTapUntil = Date.distantPast

        init(parent: SystemTimePicker) { self.parent = parent }
        func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { (component == 0 ? 24 : 60) * 200 }
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.text = String(format: "%02d", row % (component == 0 ? 24 : 60))
            label.font = parent.appearance.wheelFont
            label.textAlignment = .center
            label.textColor = parent.appearance.unselectedTextColor
            return label
        }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { parent.appearance.rowHeight }
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let selected = TimeInput(hour: pickerView.selectedRow(inComponent: 0) % 24, minute: pickerView.selectedRow(inComponent: 1) % 60)!
            if selected != displayedTime {
                ignoreTapUntil = Date().addingTimeInterval(0.4)
                parent.onWheelDragBegan()
            }
            displayedTime = selected
            parent.time = selected
        }
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard Date() >= ignoreTapUntil, let picker = recognizer.view as? UIPickerView else {
                tappedColumn = nil; modeBeforeTap = nil; return
            }
            parent.onComponentTapped(tappedColumn ?? component(at: recognizer.location(in: picker), picker: picker), modeBeforeTap ?? parent.controlMode)
            tappedColumn = nil; modeBeforeTap = nil
        }
        @objc func handleWheelPan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .began else { return }
            ignoreTapUntil = Date().addingTimeInterval(0.4)
            parent.onWheelDragBegan()
        }
        func observeWheelPans(in picker: UIView) {
            scrollViews(in: picker).forEach { scrollView in
                let id = ObjectIdentifier(scrollView.panGestureRecognizer)
                guard observedPanIDs.insert(id).inserted else { return }
                scrollView.panGestureRecognizer.addTarget(self, action: #selector(handleWheelPan(_:)))
            }
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let picker = gestureRecognizer.view as? UIPickerView else { return true }
            tappedColumn = component(at: touch.location(in: picker), picker: picker)
            modeBeforeTap = parent.controlMode
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool { gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer }
        private func component(at location: CGPoint, picker: UIPickerView) -> TimeInputControlMode { location.x < picker.bounds.midX ? .hour : .minute }
        private func scrollViews(in view: UIView) -> [UIScrollView] { view.subviews.compactMap { $0 as? UIScrollView } + view.subviews.flatMap { scrollViews(in: $0) } }
    }
}

private final class TimePickerContainerView: UIView {
    let picker = UIPickerView()
    let selectionOverlay: TimePickerSelectionOverlay
    init(appearance: TimeInputPickerAppearance) {
        selectionOverlay = TimePickerSelectionOverlay(appearance: appearance)
        super.init(frame: .zero)
        picker.translatesAutoresizingMaskIntoConstraints = false
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(picker); addSubview(selectionOverlay)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: leadingAnchor), picker.trailingAnchor.constraint(equalTo: trailingAnchor),
            picker.topAnchor.constraint(equalTo: topAnchor), picker.bottomAnchor.constraint(equalTo: bottomAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: picker.leadingAnchor), selectionOverlay.trailingAnchor.constraint(equalTo: picker.trailingAnchor),
            selectionOverlay.centerYAnchor.constraint(equalTo: picker.centerYAnchor), selectionOverlay.heightAnchor.constraint(equalToConstant: appearance.selectionBarHeight)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func alignSelectionOverlayToPickerColumns() {
        let hourRow = picker.view(forRow: picker.selectedRow(inComponent: 0), forComponent: 0)
        let minuteRow = picker.view(forRow: picker.selectedRow(inComponent: 1), forComponent: 1)
        guard let hourRow, let minuteRow else { return }
        selectionOverlay.setColumnCenters(
            hour: hourRow.superview?.convert(hourRow.center, to: self) ?? hourRow.convert(CGPoint(x: hourRow.bounds.midX, y: hourRow.bounds.midY), to: self),
            minute: minuteRow.superview?.convert(minuteRow.center, to: self) ?? minuteRow.convert(CGPoint(x: minuteRow.bounds.midX, y: minuteRow.bounds.midY), to: self)
        )
    }
}

private final class TimePickerSelectionOverlay: UIView {
    private let selectionMask = UIView()
    private let selectionBar = UIView()
    private let hourLabel = UILabel()
    private let separatorLabel = UILabel()
    private let minuteLabel = UILabel()
    private let appearance: TimeInputPickerAppearance
    private var isVisible = true
    private var hourCenter: CGFloat?
    private var minuteCenter: CGFloat?
    init(appearance: TimeInputPickerAppearance) {
        self.appearance = appearance
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        selectionMask.backgroundColor = appearance.selectionMaskColor
        selectionMask.isOpaque = true
        selectionBar.backgroundColor = appearance.selectionBackgroundColor
        selectionBar.layer.cornerRadius = appearance.selectionBarCornerRadius
        selectionBar.layer.cornerCurve = .continuous
        [hourLabel, separatorLabel, minuteLabel].forEach {
            $0.font = appearance.selectedFont
            $0.textAlignment = .center
        }
        separatorLabel.text = ":"
        addSubview(selectionMask); addSubview(selectionBar)
        [hourLabel, separatorLabel, minuteLabel].forEach(addSubview)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func apply(time: TimeInput, controlMode: TimeInputControlMode, visible: Bool, animated: Bool) {
        hourLabel.text = String(format: "%02d", time.hour); minuteLabel.text = String(format: "%02d", time.minute)
        hourLabel.textColor = active(.hour, controlMode) ? appearance.selectedTextColor : appearance.unselectedTextColor
        minuteLabel.textColor = active(.minute, controlMode) ? appearance.selectedTextColor : appearance.unselectedTextColor
        separatorLabel.textColor = controlMode == .fullTime ? appearance.selectedTextColor : appearance.unselectedTextColor
        guard isVisible != visible else { return }
        isVisible = visible
        let change = { self.alpha = visible ? 1 : 0 }
        animated ? UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: change) : change()
    }
    func setColumnCenters(hour: CGPoint, minute: CGPoint) { hourCenter = hour.x; minuteCenter = minute.x; setNeedsLayout() }
    private func active(_ column: TimeInputControlMode, _ mode: TimeInputControlMode) -> Bool { mode == .fullTime || mode == column }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width / 3, hour = hourCenter ?? width, minute = minuteCenter ?? width * 2
        selectionMask.frame = bounds
        let inset = bounds.width * appearance.selectionHorizontalInset
        selectionBar.frame = CGRect(x: inset, y: 0, width: bounds.width - inset * 2, height: bounds.height)
        hourLabel.frame = CGRect(x: hour - width / 2, y: 0, width: width, height: bounds.height)
        minuteLabel.frame = CGRect(x: minute - width / 2, y: 0, width: width, height: bounds.height)
        separatorLabel.frame = CGRect(x: bounds.midX - 18, y: 0, width: 36, height: bounds.height)
    }
}

private struct NumberPadKeyCapture: UIViewRepresentable {
    @Binding var wantsKeyboard: Bool
    let onDigit: (Character) -> Void
    let onDelete: () -> Void
    func makeUIView(context: Context) -> NumberPadCaptureTextField {
        let field = NumberPadCaptureTextField(); field.onDigit = onDigit; field.onDelete = onDelete; field.shouldRequestKeyboard = wantsKeyboard; return field
    }
    func updateUIView(_ field: NumberPadCaptureTextField, context: Context) { field.onDigit = onDigit; field.onDelete = onDelete; field.shouldRequestKeyboard = wantsKeyboard }
}

private final class NumberPadCaptureTextField: UITextField, UITextFieldDelegate {
    var onDigit: ((Character) -> Void)?
    var onDelete: (() -> Void)?
    var shouldRequestKeyboard = false { didSet { synchronizeKeyboardState() } }
    override init(frame: CGRect) {
        super.init(frame: frame)
        keyboardType = .numberPad; delegate = self; text = "\u{200B}"; tintColor = .clear; textColor = .clear; backgroundColor = .clear; accessibilityElementsHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty { onDelete?() } else { string.filter(\.isNumber).forEach { onDigit?($0) } }
        return false
    }
    override func didMoveToWindow() { super.didMoveToWindow(); synchronizeKeyboardState() }
    private func synchronizeKeyboardState() {
        guard window != nil else { return }
        if !shouldRequestKeyboard { if isFirstResponder { resignFirstResponder() }; return }
        guard !isFirstResponder else { return }
        DispatchQueue.main.async { [weak self] in guard let self, self.shouldRequestKeyboard, self.window != nil, !self.isFirstResponder else { return }; self.becomeFirstResponder() }
    }
}
