using WheelDeck.Core.Output;
using WheelDeck.Core.Protocol;

namespace WheelDeck.Core.Input;

/// <summary>
/// Translates incoming state and button messages into virtual output calls. Axes always
/// map to SetAxis; dashboard controls route through the hybrid priority described on
/// <see cref="ApplyButton"/>. Default mode is simulated key presses, matching ETS2's
/// default keybindings. Binding tables are preset-scoped (REQ-018): each layout
/// preset may overlay its own defaults, falling back to the Sequential tables.
/// </summary>
public sealed class InputMapper
{
    /// <summary>Default preset scope: the global tables below are its own.</summary>
    public const string SequentialPreset = "Sequential";

    /// <summary>Active layout preset, set from the mapping frame's preset
    /// field. Unknown names fall back to the Sequential tables.</summary>
    public string ActivePreset { get; set; } = SequentialPreset;

    /// <summary>Per-preset key overlays. Empty today: every preset shares the
    /// Sequential defaults (PRND intentionally stays unbound per the
    /// user-set-able convention), so lookups fall through to the globals.
    /// Add a preset entry here the day its defaults diverge.</summary>
    private static readonly IReadOnlyDictionary<string, IReadOnlyDictionary<ControlId, KeyCode>> PresetKeyOverlays =
        new Dictionary<string, IReadOnlyDictionary<ControlId, KeyCode>>();

    /// <summary>Per-preset button overlays, same fall-through rule as
    /// <see cref="PresetKeyOverlays"/>.</summary>
    private static readonly IReadOnlyDictionary<string, IReadOnlyDictionary<ControlId, ButtonId>> PresetButtonOverlays =
        new Dictionary<string, IReadOnlyDictionary<ControlId, ButtonId>>();

    private static readonly IReadOnlyDictionary<ControlId, KeyCode> DefaultKeyBindings =
        new Dictionary<ControlId, KeyCode>
        {
            [ControlId.ParkingBrake] = KeyCode.Space,
            [ControlId.TurnSignalLeft] = KeyCode.LeftBracket,
            [ControlId.TurnSignalRight] = KeyCode.RightBracket,
            [ControlId.HeadlightToggle] = KeyCode.L,
            // Phone-held light cycle: three distinct IDs, one headlight key.
            // ETS2 advances its own light state per pulse.
            [ControlId.LightsOff] = KeyCode.L,
            [ControlId.LightsParking] = KeyCode.L,
            [ControlId.LightsLowbeam] = KeyCode.L,
            [ControlId.HighBeamToggle] = KeyCode.K,
            [ControlId.Wipers] = KeyCode.P,
            [ControlId.CruiseToggle] = KeyCode.C,
            [ControlId.CruiseSetResume] = KeyCode.R,
            [ControlId.EngineStart] = KeyCode.E,
            [ControlId.HazardLights] = KeyCode.F,
            [ControlId.BeaconLights] = KeyCode.O,
            [ControlId.Flasher] = KeyCode.J,
            [ControlId.Horn] = KeyCode.H,
            [ControlId.Trailer] = KeyCode.T,
            [ControlId.LiftDropAxle] = KeyCode.U,
            [ControlId.CameraView] = KeyCode.Digit9,
            [ControlId.GearUp] = KeyCode.LeftShift,
            [ControlId.GearDown] = KeyCode.LeftCtrl,
            [ControlId.EngineBrake] = KeyCode.B,
            [ControlId.AirHorn] = KeyCode.N,
            [ControlId.DifferentialLock] = KeyCode.V,
            [ControlId.RetarderIncrease] = KeyCode.Semicolon,
            [ControlId.RetarderDecrease] = KeyCode.Quote,
            [ControlId.QuickInfo] = KeyCode.F1,
            [ControlId.MirrorToggle] = KeyCode.F2,
            [ControlId.HudWidgets] = KeyCode.F3,
            [ControlId.VehicleAdjustment] = KeyCode.F4,
            [ControlId.NavigationZoomOut] = KeyCode.F5,
            [ControlId.WidgetOptions] = KeyCode.F6,
            [ControlId.Services] = KeyCode.F7,
            [ControlId.QuickSave] = KeyCode.ScrollLock,
            [ControlId.QuickLoad] = KeyCode.Pause,
            [ControlId.Screenshot] = KeyCode.F10,
            [ControlId.GarageManager] = KeyCode.G,
            [ControlId.AudioPlayer] = KeyCode.R,
            // User-set-able controls default to empty: no key by design. The
            // phone gates them (sends nothing); None is inert in every backend.
            [ControlId.ShiftToDrive] = KeyCode.None,
            [ControlId.ShiftToReverse] = KeyCode.None,
            [ControlId.ShiftToNeutral] = KeyCode.None,
            [ControlId.EngineElectricity] = KeyCode.None,
            [ControlId.AdaptiveCruise] = KeyCode.None,
            [ControlId.CruiseSpeedIncrease] = KeyCode.None,
            [ControlId.CruiseSpeedDecrease] = KeyCode.None,
            [ControlId.LaneAssistant] = KeyCode.None,
            [ControlId.LaneKeeping] = KeyCode.None,
            [ControlId.EmergencyBrake] = KeyCode.None,
            [ControlId.WipersBack] = KeyCode.None,
            [ControlId.AudioPlayPause] = KeyCode.K,
            [ControlId.AudioNext] = KeyCode.U,
            [ControlId.AudioPrevious] = KeyCode.J,
            [ControlId.AudioVolumeUp] = KeyCode.O,
            [ControlId.AudioVolumeDown] = KeyCode.L,
            [ControlId.AudioFavorite] = KeyCode.None,
            // Trailer and trailer axle share T per the researched defaults.
            [ControlId.TrailerAxle] = KeyCode.T,
            [ControlId.DriverWindowUp] = KeyCode.RightShift,
            [ControlId.NavigationZoomIn] = KeyCode.Slash,
            [ControlId.DriverWindowDown] = KeyCode.RightCtrl,
            [ControlId.PassengerWindowUp] = KeyCode.Comma,
            [ControlId.PassengerWindowDown] = KeyCode.Dot,
            [ControlId.OverlayActivation] = KeyCode.Tab,
            [ControlId.ChatActivation] = KeyCode.Y,
            [ControlId.QuickReplies] = KeyCode.Q,
            [ControlId.NameTags] = KeyCode.Z,
            [ControlId.PushToTalk] = KeyCode.X,
            [ControlId.CameraInterior] = KeyCode.Digit1,
            [ControlId.CameraChasing] = KeyCode.Digit2,
            [ControlId.CameraTopdown] = KeyCode.Digit3,
            [ControlId.CameraRoof] = KeyCode.Digit4,
            [ControlId.CameraLeanout] = KeyCode.Digit5,
            [ControlId.DashboardInfo] = KeyCode.I,
            // Next camera shares Digit9 with camera view per the defaults.
            [ControlId.NextCamera] = KeyCode.Digit9,
            [ControlId.Menu] = KeyCode.Escape,
            [ControlId.WorldMap] = KeyCode.M,
            [ControlId.PhotoMode] = KeyCode.EqualSign,
            [ControlId.Activate] = KeyCode.Enter,
            // Camera pad resolves to the numpad keys (REQ-017); the arrow set
            // maps to the arrow keys. Both sets are keyboard-only.
            [ControlId.CameraPadUp] = KeyCode.Numpad8,
            [ControlId.CameraPadDown] = KeyCode.Numpad2,
            [ControlId.CameraPadLeft] = KeyCode.Numpad4,
            [ControlId.CameraPadRight] = KeyCode.Numpad6,
            [ControlId.CameraPadUpLeft] = KeyCode.Numpad7,
            [ControlId.CameraPadUpRight] = KeyCode.Numpad9,
            [ControlId.CameraPadDownLeft] = KeyCode.Numpad1,
            [ControlId.CameraPadDownRight] = KeyCode.Numpad3,
            [ControlId.CameraPadRecenter] = KeyCode.Numpad5,
            [ControlId.CameraPadArrowUp] = KeyCode.ArrowUp,
            [ControlId.CameraPadArrowDown] = KeyCode.ArrowDown,
            [ControlId.CameraPadArrowLeft] = KeyCode.ArrowLeft,
            [ControlId.CameraPadArrowRight] = KeyCode.ArrowRight
        };

    private static readonly IReadOnlyDictionary<ControlId, ButtonId> DefaultButtonBindings =
        new Dictionary<ControlId, ButtonId>
        {
            [ControlId.ParkingBrake] = ButtonId.A,
            [ControlId.TurnSignalLeft] = ButtonId.DPadLeft,
            [ControlId.TurnSignalRight] = ButtonId.DPadRight,
            [ControlId.HeadlightToggle] = ButtonId.B,
            [ControlId.LightsOff] = ButtonId.B,
            [ControlId.LightsParking] = ButtonId.B,
            [ControlId.LightsLowbeam] = ButtonId.B,
            [ControlId.HighBeamToggle] = ButtonId.Y,
            [ControlId.Wipers] = ButtonId.X,
            [ControlId.CruiseToggle] = ButtonId.LeftBumper,
            [ControlId.CruiseSetResume] = ButtonId.RightBumper,
            [ControlId.EngineStart] = ButtonId.Start,
            // Spare buttons for the driving-relevant extras. Menu-type extras
            // and the user-set-able set map to None (inert): a 15-button pad
            // cannot cover 43 ETS2 extras, and the phone gates unbound ones.
            [ControlId.HazardLights] = ButtonId.Back,
            [ControlId.Horn] = ButtonId.LeftThumb,
            [ControlId.CameraView] = ButtonId.RightThumb,
            [ControlId.GearUp] = ButtonId.DPadUp,
            [ControlId.GearDown] = ButtonId.DPadDown,
            [ControlId.BeaconLights] = ButtonId.None,
            [ControlId.Flasher] = ButtonId.None,
            [ControlId.Trailer] = ButtonId.None,
            [ControlId.LiftDropAxle] = ButtonId.None,
            [ControlId.EngineBrake] = ButtonId.None,
            [ControlId.AirHorn] = ButtonId.None,
            [ControlId.DifferentialLock] = ButtonId.None,
            [ControlId.RetarderIncrease] = ButtonId.None,
            [ControlId.RetarderDecrease] = ButtonId.None,
            [ControlId.QuickInfo] = ButtonId.None,
            [ControlId.MirrorToggle] = ButtonId.None,
            [ControlId.HudWidgets] = ButtonId.None,
            [ControlId.VehicleAdjustment] = ButtonId.None,
            [ControlId.NavigationZoomOut] = ButtonId.None,
            [ControlId.WidgetOptions] = ButtonId.None,
            [ControlId.Services] = ButtonId.None,
            [ControlId.QuickSave] = ButtonId.None,
            [ControlId.QuickLoad] = ButtonId.None,
            [ControlId.Screenshot] = ButtonId.None,
            [ControlId.GarageManager] = ButtonId.None,
            [ControlId.AudioPlayer] = ButtonId.None,
            [ControlId.ShiftToDrive] = ButtonId.None,
            [ControlId.ShiftToReverse] = ButtonId.None,
            [ControlId.ShiftToNeutral] = ButtonId.None,
            [ControlId.EngineElectricity] = ButtonId.None,
            [ControlId.AdaptiveCruise] = ButtonId.None,
            [ControlId.CruiseSpeedIncrease] = ButtonId.None,
            [ControlId.CruiseSpeedDecrease] = ButtonId.None,
            [ControlId.LaneAssistant] = ButtonId.None,
            [ControlId.LaneKeeping] = ButtonId.None,
            [ControlId.EmergencyBrake] = ButtonId.None,
            [ControlId.WipersBack] = ButtonId.None,
            [ControlId.AudioPlayPause] = ButtonId.None,
            [ControlId.AudioNext] = ButtonId.None,
            [ControlId.AudioPrevious] = ButtonId.None,
            [ControlId.AudioVolumeUp] = ButtonId.None,
            [ControlId.AudioVolumeDown] = ButtonId.None,
            [ControlId.AudioFavorite] = ButtonId.None,
            [ControlId.TrailerAxle] = ButtonId.None,
            [ControlId.DriverWindowUp] = ButtonId.None,
            [ControlId.DriverWindowDown] = ButtonId.None,
            [ControlId.PassengerWindowUp] = ButtonId.None,
            [ControlId.PassengerWindowDown] = ButtonId.None,
            [ControlId.NavigationZoomIn] = ButtonId.None,
            [ControlId.OverlayActivation] = ButtonId.None,
            [ControlId.ChatActivation] = ButtonId.None,
            [ControlId.QuickReplies] = ButtonId.None,
            [ControlId.NameTags] = ButtonId.None,
            [ControlId.PushToTalk] = ButtonId.None,
            [ControlId.CameraInterior] = ButtonId.None,
            [ControlId.CameraChasing] = ButtonId.None,
            [ControlId.CameraTopdown] = ButtonId.None,
            [ControlId.CameraRoof] = ButtonId.None,
            [ControlId.CameraLeanout] = ButtonId.None,
            [ControlId.DashboardInfo] = ButtonId.None,
            [ControlId.NextCamera] = ButtonId.None,
            [ControlId.Menu] = ButtonId.None,
            [ControlId.WorldMap] = ButtonId.None,
            [ControlId.PhotoMode] = ButtonId.None,
            [ControlId.Activate] = ButtonId.None,
            // The camera pad is keyboard-only: no gamepad equivalents.
            [ControlId.CameraPadUp] = ButtonId.None,
            [ControlId.CameraPadDown] = ButtonId.None,
            [ControlId.CameraPadLeft] = ButtonId.None,
            [ControlId.CameraPadRight] = ButtonId.None,
            [ControlId.CameraPadUpLeft] = ButtonId.None,
            [ControlId.CameraPadUpRight] = ButtonId.None,
            [ControlId.CameraPadDownLeft] = ButtonId.None,
            [ControlId.CameraPadDownRight] = ButtonId.None,
            [ControlId.CameraPadRecenter] = ButtonId.None,
            [ControlId.CameraPadArrowUp] = ButtonId.None,
            [ControlId.CameraPadArrowDown] = ButtonId.None,
            [ControlId.CameraPadArrowLeft] = ButtonId.None,
            [ControlId.CameraPadArrowRight] = ButtonId.None
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
    /// <remarks>
    /// Hybrid routing: the mapping mode is a route priority, not an exclusivity
    /// switch. In gamepad mode a control presses its virtual controller button
    /// when one is bound, otherwise its keyboard key; in keyboard mode the
    /// priority is reversed. A control bound to None in both tables stays
    /// inert. Recorded here because this dispatch is the single point where
    /// the mode meets the binding tables. The mode arrives from the phone's
    /// mapping frame; switching modes mid-hold is a deliberate user action and
    /// can strand a held key or button — accepted, as in the prior exclusive
    /// dispatch.
    /// </remarks>
    public void ApplyButton(ButtonMessage button)
    {
        if (Mode == MappingMode.ControllerButton)
        {
            if (!TryRouteButton(button))
            {
                TryRouteKey(button);
            }
        }
        else if (!TryRouteKey(button))
        {
            TryRouteButton(button);
        }
    }

    private bool TryRouteButton(ButtonMessage button)
    {
        if (!TryGetButtonBinding(button.Control, out var buttonId) ||
            buttonId == ButtonId.None)
        {
            return false;
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

        return true;
    }

    private bool TryRouteKey(ButtonMessage button)
    {
        if (!TryGetKeyBinding(button.Control, out var keyCode) ||
            keyCode == KeyCode.None)
        {
            return false;
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

        return true;
    }

    /// <summary>Preset-scoped key lookup: the active preset's overlay wins,
    /// unknown presets and missing entries fall back to the Sequential
    /// globals, keeping the hybrid priority intact.</summary>
    private bool TryGetKeyBinding(ControlId control, out KeyCode keyCode)
    {
        if (PresetKeyOverlays.TryGetValue(ActivePreset, out var overlay) &&
            overlay.TryGetValue(control, out keyCode))
        {
            return true;
        }

        return DefaultKeyBindings.TryGetValue(control, out keyCode);
    }

    /// <summary>Preset-scoped button lookup, same fall-through rule as
    /// <see cref="TryGetKeyBinding"/>.</summary>
    private bool TryGetButtonBinding(ControlId control, out ButtonId buttonId)
    {
        if (PresetButtonOverlays.TryGetValue(ActivePreset, out var overlay) &&
            overlay.TryGetValue(control, out buttonId))
        {
            return true;
        }

        return DefaultButtonBindings.TryGetValue(control, out buttonId);
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
