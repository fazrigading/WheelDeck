using WheelDeck.Core.Output;
using WheelDeck.Core.Protocol;

namespace WheelDeck.Core.Input;

/// <summary>
/// Translates incoming state and button messages into virtual output calls. Axes always
/// map to SetAxis; dashboard controls route to SetButton or SendKey based on MappingMode.
/// Default mode is simulated key presses, matching ETS2's default keybindings.
/// </summary>
public sealed class InputMapper
{
    private static readonly IReadOnlyDictionary<ControlId, KeyCode> DefaultKeyBindings =
        new Dictionary<ControlId, KeyCode>
        {
            [ControlId.ParkingBrake] = KeyCode.Space,
            [ControlId.TurnSignalLeft] = KeyCode.LeftBracket,
            [ControlId.TurnSignalRight] = KeyCode.RightBracket,
            [ControlId.HeadlightToggle] = KeyCode.L,
            [ControlId.HighBeamToggle] = KeyCode.K,
            [ControlId.Wipers] = KeyCode.P,
            [ControlId.CruiseToggle] = KeyCode.C,
            [ControlId.CruiseSetResume] = KeyCode.R,
            [ControlId.EngineStart] = KeyCode.E
        };

    private static readonly IReadOnlyDictionary<ControlId, ButtonId> DefaultButtonBindings =
        new Dictionary<ControlId, ButtonId>
        {
            [ControlId.ParkingBrake] = ButtonId.A,
            [ControlId.TurnSignalLeft] = ButtonId.DPadLeft,
            [ControlId.TurnSignalRight] = ButtonId.DPadRight,
            [ControlId.HeadlightToggle] = ButtonId.B,
            [ControlId.HighBeamToggle] = ButtonId.Y,
            [ControlId.Wipers] = ButtonId.X,
            [ControlId.CruiseToggle] = ButtonId.LeftBumper,
            [ControlId.CruiseSetResume] = ButtonId.RightBumper,
            [ControlId.EngineStart] = ButtonId.Start
        };

    private readonly VirtualOutputBackend _backend;

    public InputMapper(VirtualOutputBackend backend)
    {
        _backend = backend;
    }

    /// <summary>How dashboard controls are routed. Defaults to simulated key presses.</summary>
    public MappingMode Mode { get; set; } = MappingMode.SimulatedKeyPress;

    /// <summary>Routes a continuous state message to the analog axes.</summary>
    public void ApplyState(StateMessage state)
    {
        _backend.SetAxis(AxisType.Steering, (float)Clamp(state.Steering, -1.0, 1.0));
        _backend.SetAxis(AxisType.Accelerator, (float)Clamp(state.Accelerator, 0.0, 1.0));
        _backend.SetAxis(AxisType.Brake, (float)Clamp(state.Brake, 0.0, 1.0));
        _backend.SetAxis(AxisType.Clutch, (float)Clamp(state.Clutch, 0.0, 1.0));
    }

    /// <summary>Routes a discrete button event according to the current mapping mode.</summary>
    public void ApplyButton(ButtonMessage button)
    {
        if (Mode == MappingMode.ControllerButton)
        {
            RouteButton(button);
        }
        else
        {
            RouteKey(button);
        }
    }

    private void RouteButton(ButtonMessage button)
    {
        if (!DefaultButtonBindings.TryGetValue(button.Control, out var buttonId))
        {
            return;
        }

        switch (button.Action)
        {
            case ActionType.Press:
                _backend.SetButton(buttonId, true);
                break;
            case ActionType.Release:
                _backend.SetButton(buttonId, false);
                break;
            case ActionType.Toggle:
            case ActionType.HoldConfirm:
                _backend.SetButton(buttonId, true);
                _backend.SetButton(buttonId, false);
                break;
        }
    }

    private void RouteKey(ButtonMessage button)
    {
        if (!DefaultKeyBindings.TryGetValue(button.Control, out var keyCode))
        {
            return;
        }

        switch (button.Action)
        {
            case ActionType.Press:
                _backend.SendKey(keyCode, true);
                break;
            case ActionType.Release:
                _backend.SendKey(keyCode, false);
                break;
            case ActionType.Toggle:
            case ActionType.HoldConfirm:
                _backend.SendKey(keyCode, true);
                _backend.SendKey(keyCode, false);
                break;
        }
    }

    private static double Clamp(double value, double min, double max)
    {
        if (value < min)
        {
            return min;
        }

        return value > max ? max : value;
    }
}
