import Combine
import Foundation
import GameController

@MainActor
final class ControllerInputModel: ObservableObject {
    @Published private(set) var status = "No controller connected"
    @Published private(set) var leftStick = SIMD2<Float>(repeating: 0)
    @Published private(set) var rightStick = SIMD2<Float>(repeating: 0)
    @Published private(set) var pressedButtons: Set<String> = []
    @Published private(set) var controllerName = "—"

    private var connectedController: GCController?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in self?.attach(controller) }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in
                if self?.connectedController === controller { self?.detach() }
            }
        })
        if let existing = GCController.controllers().first { attach(existing) }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func attach(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else {
            status = "Connected, but no extended gamepad profile is exposed"
            return
        }
        connectedController = controller
        controllerName = controller.vendorName ?? "Game Controller"
        status = "Connected — buttons and sticks only"
        gamepad.valueChangedHandler = { [weak self] pad, _ in
            let left = SIMD2<Float>(pad.leftThumbstick.xAxis.value, pad.leftThumbstick.yAxis.value)
            let right = SIMD2<Float>(pad.rightThumbstick.xAxis.value, pad.rightThumbstick.yAxis.value)
            var buttons = Set<String>()
            if pad.buttonA.isPressed { buttons.insert("A") }
            if pad.buttonB.isPressed { buttons.insert("B") }
            if pad.buttonX.isPressed { buttons.insert("X") }
            if pad.buttonY.isPressed { buttons.insert("Y") }
            if pad.leftShoulder.isPressed { buttons.insert("L") }
            if pad.rightShoulder.isPressed { buttons.insert("R") }
            if pad.leftTrigger.isPressed { buttons.insert("ZL") }
            if pad.rightTrigger.isPressed { buttons.insert("ZR") }
            if pad.buttonMenu.isPressed { buttons.insert("Menu") }
            if pad.buttonOptions?.isPressed == true { buttons.insert("Options") }
            if pad.buttonHome?.isPressed == true { buttons.insert("Home") }
            if pad.dpad.up.isPressed { buttons.insert("Up") }
            if pad.dpad.down.isPressed { buttons.insert("Down") }
            if pad.dpad.left.isPressed { buttons.insert("Left") }
            if pad.dpad.right.isPressed { buttons.insert("Right") }
            Task { @MainActor [weak self] in
                self?.leftStick = left
                self?.rightStick = right
                self?.pressedButtons = buttons
            }
        }
    }

    private func detach() {
        connectedController?.extendedGamepad?.valueChangedHandler = nil
        connectedController = nil
        controllerName = "—"
        status = "No controller connected"
        leftStick = .zero
        rightStick = .zero
        pressedButtons = []
    }
}
