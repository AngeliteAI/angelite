pub const Key = enum {
    Q,
    W,
    E,
    R,
    T,
    Y,
    U,
    I,
    O,
    P,
    A,
    S,
    D,
    F,
    G,
    H,
    J,
    K,
    L,
    Z,
    X,
    C,
    V,
    B,
    N,
    M,
    Space,
}

pub const MouseButton = enum {
                            Left,
                            Right,
                            Middle,
                            X1,
                            X2,
                        };

pub const GamepadButton = enum {
                            A,
                            B,
                            X,
                            Y,
                            LeftShoulder,
                            RightShoulder,
                            Back,
                            Start,
                            Guide,
                            LeftStick,
                            RightStick,
                            DPadUp,
                            DPadDown,
                            DPadLeft,
                            DPadRight,
                        };

pub const ButtonBinding = extern struct {
    ty: enum {
        Keyboard,
        Mouse,
        Gamepad,
    },
    code: union {
        Keyboard: struct {
            key: Key
        },
        Mouse: struct {
            button: MouseButton,
        },
        Gamepad: struct {
            button: GamepadButton
        },
    }
}

pub const AxisBinding = extern struct {
    axis: enum {
        X,
        Y,
        Z
    },
    ty: enum {
        Mouse,
        Scroll,
        Joystick,
        Trigger
    },
    side: ?enum {
        Left,
        Right
    },
}

pub const Binding = extern struct {
    ty: enum {
            Button,
            Axis,
        },
    data: union {
        Button {
            binding: ButtonBinding,
        },
        Axis {
            binding: AxisBinding,
        }
    }
}

pub const Control = extern struct {
    ty: enum {
        Button,
        Axis,
    },
    data: union {
        Button: struct {
            action: enum {
                Deactivate,
                Activate,
                Continuous
            },
        },
        Axis: struct {
            movement: f32,
        }
    }
}
