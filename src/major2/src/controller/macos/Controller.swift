import Foundation
import GameController

public typealias ControllerButtonCallback = @convention(c) (UInt32, Bool) -> Void
public typealias ControllerAnalogCallback = @convention(c) (UInt32, Float, Float) -> Void

public enum Button: UInt32 {
    // Face buttons
    case buttonA = 0
    case buttonB = 1
    case buttonX = 2
    case buttonY = 3

    // Shoulder buttons
    case leftShoulder = 4
    case rightShoulder = 5

    // Triggers
    case leftTrigger = 6
    case rightTrigger = 7

    // D-pad
    case dpadUp = 8
    case dpadDown = 9
    case dpadLeft = 10
    case dpadRight = 11

    // Thumbsticks
    case leftThumbstick = 12
    case rightThumbstick = 13
    case leftThumbstickButton = 14
    case rightThumbstickButton = 15

    // Menu buttons
    case buttonMenu = 16
    case buttonOptions = 17
    case buttonHome = 18
}

class Controllers {
    static let shared = Controllers()

    public var controllers: [GCController] = []

    private var buttonStates: [Button: Bool] = [:]

    private var buttonCallback: ControllerButtonCallback?
    private var analogCallback: ControllerAnalogCallback?


    private init() {
        setupControllerObservers()
    }

    public func setButtonCallback(_ callback: @escaping ControllerButtonCallback) {
        self.buttonCallback = callback
    }

    public func setAnalogCallback(_ callback: @escaping ControllerAnalogCallback) {
        self.analogCallback = callback
    }

    private func setupControllerObservers() {
        // Register for connection notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected),
            name: .GCControllerDidConnect,
            object: nil
        )

        // Register for disconnection notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Start scanning for controllers
        GCController.startWirelessControllerDiscovery {}
    }

    @objc private func controllerConnected(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }

        controllers.append(controller)
        print("Controller connected: \(controller.vendorName ?? "Unknown")")
        // Controller connected, notify through callback
        // Report controller connection to FFI
        buttonCallback?(Button.buttonHome.rawValue, true)

        // Setup Xbox controller input handlers
        setupExtendedGamepad(controller)
    }

    @objc private func controllerDisconnected(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }

        if let index = controllers.firstIndex(of: controller) {
            controllers.remove(at: index)
            print("Controller disconnected: \(controller.vendorName ?? "Unknown")")

            // Report controller disconnection to FFI
            buttonCallback?(Button.buttonHome.rawValue, false)
        }
    }

    // Public methods for FFI

    /// Start controller discovery - can be called from FFI
    @objc public func startControllerDiscovery() {
        GCController.startWirelessControllerDiscovery {}
    }

    /// Check if a specific button is pressed - can be called from FFI
    @objc public func isButtonPressed(_ buttonId: UInt32) -> Bool {
        guard let button = Button(rawValue: buttonId) else { return false }
        return buttonStates[button] ?? false
    }
}

extension Controllers {
    private func setupExtendedGamepad(_ controller: GCController) {
        // For Xbox controllers, we use the extended gamepad profile
        guard let gamepad = controller.extendedGamepad else { return }

        // Handle button inputs
        gamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .buttonA, isPressed: pressed)
        }

        gamepad.buttonB.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .buttonB, isPressed: pressed)
        }

        gamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .buttonX, isPressed: pressed)
        }

        gamepad.buttonY.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .buttonY, isPressed: pressed)
        }

        gamepad.leftShoulder.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .leftShoulder, isPressed: pressed)
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .rightShoulder, isPressed: pressed)
        }

        // D-pad buttons
        gamepad.dpad.up.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .dpadUp, isPressed: pressed)
        }

        gamepad.dpad.down.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .dpadDown, isPressed: pressed)
        }

        gamepad.dpad.left.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .dpadLeft, isPressed: pressed)
        }

        gamepad.dpad.right.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .dpadRight, isPressed: pressed)
        }

        gamepad.buttonMenu.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .buttonMenu, isPressed: pressed)
        }

        gamepad.buttonOptions?.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .buttonOptions, isPressed: pressed)
        }

        // Thumbstick buttons
        gamepad.leftThumbstickButton?.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .leftThumbstickButton, isPressed: pressed)
        }

        gamepad.rightThumbstickButton?.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.handleButtonChange(button: .rightThumbstickButton, isPressed: pressed)
        }

        // Handle analog triggers
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (trigger, value, pressed) in
            self?.handleAnalogInput(input: .leftTrigger, x: value, y: 0)
        }

        gamepad.rightTrigger.valueChangedHandler = { [weak self] (trigger, value, pressed) in
            self?.handleAnalogInput(input: .rightTrigger, x: value, y: 0)
        }

        // Handle thumbstick movements
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (thumbstick, xValue, yValue) in
            self?.handleAnalogInput(input: .leftThumbstick, x: xValue, y: yValue)
        }

        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (thumbstick, xValue, yValue) in
            self?.handleAnalogInput(input: .rightThumbstick, x: xValue, y: yValue)
        }
    }

    private func handleButtonChange(button: Button, isPressed: Bool) {
        // Update internal state
        buttonStates[button] = isPressed
        // Button state changed

        // Call FFI callback
        buttonCallback?(button.rawValue, isPressed)
    }

    private func handleAnalogInput(input: Button, x: Float, y: Float) {
        // Call FFI callback for analog inputs
        analogCallback?(input.rawValue, x, y)
    }
}


@_cdecl("controller_get_shared_instance")
public func controller_get_shared_instance() -> UnsafeMutableRawPointer {
    // Return the shared instance as a pointer that can be used in future FFI calls
    return Unmanaged.passRetained(Controllers.shared).toOpaque()
}

@_cdecl("controller_release_instance")
public func controller_release_instance(_ instancePtr: UnsafeMutableRawPointer) {
    // Release the instance when Rust is done with it
    Unmanaged<Controllers>.fromOpaque(instancePtr).release()
}

@_cdecl("controller_set_button_callback")
public func controller_set_button_callback(_ callback: @escaping ControllerButtonCallback) {
    Controllers.shared.setButtonCallback(callback)
}

@_cdecl("controller_set_analog_callback")
public func controller_set_analog_callback(_ callback: @escaping ControllerAnalogCallback) {
    Controllers.shared.setAnalogCallback(callback)
}

@_cdecl("controller_start_discovery")
public func controller_start_discovery() {
    Controllers.shared.startControllerDiscovery()
}

@_cdecl("controller_is_button_pressed")
public func controller_is_button_pressed(_ buttonId: UInt32) -> Bool {
    return Controllers.shared.isButtonPressed(buttonId)
}

@_cdecl("controller_get_connected_count")
public func controller_get_connected_count() -> Int32 {
    return Int32(Controllers.shared.controllers.count)
}

// Helper function to convert Swift strings to C strings for FFI
private func stringToCString(_ string: String) -> UnsafeMutablePointer<Int8> {
    let cString = strdup(string)
    return cString!
}

@_cdecl("controller_get_controller_name")
public func controller_get_controller_name(_ index: Int32) -> UnsafeMutablePointer<Int8>? {
    let manager = Controllers.shared
    guard index >= 0, index < manager.controllers.count else {
        return stringToCString("")
    }

    let name = manager.controllers[Int(index)].vendorName ?? "Unknown Controller"
    return stringToCString(name)
}
