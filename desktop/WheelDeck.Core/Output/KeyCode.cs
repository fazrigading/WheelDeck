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
    Escape
}
