namespace WheelDeck.Core.Input;

/// <summary>
/// How the input mapper translates dashboard controls into output. SimulatedKeyPress is
/// the default, matching ETS2's default keybindings.
/// </summary>
public enum MappingMode
{
    /// <summary>Dashboard controls become simulated keyboard presses.</summary>
    SimulatedKeyPress,

    /// <summary>Dashboard controls become virtual-controller button presses.</summary>
    ControllerButton
}
