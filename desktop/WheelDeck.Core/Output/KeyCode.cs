namespace WheelDeck.Core.Output;

/// <summary>
/// Keyboard keys available to the simulated-keypress mapping mode. Letter keys cover
/// the truck controls; the exact ControlId-to-key bindings live in the input mapper.
/// </summary>
public enum KeyCode
{
    None,

    A, B, C, D, E, F, G, H, I, J, K, L, M,
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,

    Space,
    LeftBracket,
    RightBracket,
    Enter,
    Escape,

    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10,

    Digit0, Digit1, Digit2, Digit3, Digit4,
    Digit5, Digit6, Digit7, Digit8, Digit9,

    LeftShift,
    LeftCtrl,

    Semicolon,
    Quote,

    ScrollLock,
    Pause
}
