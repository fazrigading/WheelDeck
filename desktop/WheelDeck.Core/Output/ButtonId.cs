namespace WheelDeck.Core.Output;

/// Virtual-controller buttons exposed by the output backends for controller-button
/// mapping mode. Follows the standard Xbox-style button set.
public enum ButtonId
{
    /// No button. Rows mapped here are inert by design (e.g. menu-type
    /// or user-set-able controls with no sensible controller equivalent);
    /// every backend ignores unmapped buttons.
    None,
    A,
    B,
    X,
    Y,
    LeftBumper,
    RightBumper,
    Back,
    Start,
    LeftThumb,
    RightThumb,
    DPadUp,
    DPadDown,
    DPadLeft,
    DPadRight,
    Guide
}
