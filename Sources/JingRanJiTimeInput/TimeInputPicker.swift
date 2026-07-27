import SwiftUI
import UIKit

/// 时间滚轮的可定制视觉样式。
public struct TimeInputPickerStyle {
    public let selectedTextColor: UIColor
    public let selectionBackgroundColor: UIColor

    public init(selectedTextColor: UIColor, selectionBackgroundColor: UIColor = .secondarySystemFill) {
        self.selectedTextColor = selectedTextColor
        self.selectionBackgroundColor = selectionBackgroundColor
    }

    /// 与井然记暖色/曜石黑主题一致的默认样式。
    public static let jingRanJi = TimeInputPickerStyle(
        selectedTextColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 180 / 255, blue: 142 / 255, alpha: 1)
                : UIColor(red: 168 / 255, green: 74 / 255, blue: 33 / 255, alpha: 1)
        }
    )

    /// 使用宿主 App 的系统 tint 色。
    public static let system = TimeInputPickerStyle(selectedTextColor: .tintColor)
}

/// 可直接嵌入 SwiftUI 的时间输入控件。
///
/// 打开时数字键盘默认控制完整时间；拖动滚轮会收起键盘，首次轻点滚轮只唤醒键盘。
public struct TimeInputPicker: View {
    @Binding private var time: TimeInput
    private let style: TimeInputPickerStyle
    private let wheelHeight: CGFloat

    @State private var synchronizer: TimeInputSynchronizer
    @State private var selectionRequestID = 0
    @State private var wantsKeyboard = true
    @State private var awaitsKeyboardWakeAfterWheelDrag = false

    public init(
        time: Binding<TimeInput>,
        style: TimeInputPickerStyle = .jingRanJi,
        wheelHeight: CGFloat = 180
    ) {
        _time = time
        self.style = style
        self.wheelHeight = wheelHeight
        _synchronizer = State(initialValue: TimeInputSynchronizer(initialTime: time.wrappedValue))
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
            style: style,
            onComponentTapped: { component, modeBeforeTouch in
                if awaitsKeyboardWakeAfterWheelDrag {
                    synchronizer.selectControlMode(.fullTime)
                    awaitsKeyboardWakeAfterWheelDrag = false
                } else {
                    synchronizer.applyColumnTap(component, modeBeforeTouch: modeBeforeTouch)
                }
                wantsKeyboard = true
            },
            onWheelDragBegan: {
                synchronizer.beginWheelDrag()
                awaitsKeyboardWakeAfterWheelDrag = true
                wantsKeyboard = false
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
        }
        .onChange(of: time) { value in
            guard synchronizer.time != value else { return }
            synchronizer = TimeInputSynchronizer(initialTime: value)
            selectionRequestID += 1
        }
    }
}

private struct SystemTimePicker: UIViewRepresentable {
    @Binding var time: TimeInput
    let controlMode: TimeInputControlMode
    let selectionRequestID: Int
    let showsSelectionOverlay: Bool
    let style: TimeInputPickerStyle
    let onComponentTapped: (TimeInputControlMode, TimeInputControlMode) -> Void
    let onWheelDragBegan: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> TimePickerContainerView {
        let container = TimePickerContainerView(style: style)
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
            label.font = .monospacedDigitSystemFont(ofSize: 24, weight: .regular)
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            return label
        }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 30 }
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
    init(style: TimeInputPickerStyle) {
        selectionOverlay = TimePickerSelectionOverlay(style: style)
        super.init(frame: .zero)
        picker.translatesAutoresizingMaskIntoConstraints = false
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(picker); addSubview(selectionOverlay)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: leadingAnchor), picker.trailingAnchor.constraint(equalTo: trailingAnchor),
            picker.topAnchor.constraint(equalTo: topAnchor), picker.bottomAnchor.constraint(equalTo: bottomAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: picker.leadingAnchor), selectionOverlay.trailingAnchor.constraint(equalTo: picker.trailingAnchor),
            selectionOverlay.centerYAnchor.constraint(equalTo: picker.centerYAnchor), selectionOverlay.heightAnchor.constraint(equalToConstant: 32)
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
    private let style: TimeInputPickerStyle
    private var isVisible = true
    private var hourCenter: CGFloat?
    private var minuteCenter: CGFloat?
    init(style: TimeInputPickerStyle) {
        self.style = style
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        selectionMask.backgroundColor = .systemBackground
        selectionMask.isOpaque = true
        selectionBar.backgroundColor = style.selectionBackgroundColor
        selectionBar.layer.cornerRadius = 15
        selectionBar.layer.cornerCurve = .continuous
        [hourLabel, separatorLabel, minuteLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 24, weight: .regular)
            $0.textAlignment = .center
        }
        separatorLabel.text = ":"
        addSubview(selectionMask); addSubview(selectionBar)
        [hourLabel, separatorLabel, minuteLabel].forEach(addSubview)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func apply(time: TimeInput, controlMode: TimeInputControlMode, visible: Bool, animated: Bool) {
        hourLabel.text = String(format: "%02d", time.hour); minuteLabel.text = String(format: "%02d", time.minute)
        hourLabel.textColor = active(.hour, controlMode) ? style.selectedTextColor : .secondaryLabel
        minuteLabel.textColor = active(.minute, controlMode) ? style.selectedTextColor : .secondaryLabel
        separatorLabel.textColor = controlMode == .fullTime ? style.selectedTextColor : .secondaryLabel
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
        let y = (bounds.height - 30) / 2
        selectionBar.frame = CGRect(x: bounds.width * 0.08, y: y, width: bounds.width * 0.84, height: 30)
        hourLabel.frame = CGRect(x: hour - width / 2, y: y, width: width, height: 30)
        minuteLabel.frame = CGRect(x: minute - width / 2, y: y, width: width, height: 30)
        separatorLabel.frame = CGRect(x: bounds.midX - 18, y: y, width: 36, height: 30)
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
