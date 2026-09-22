using System.Reflection;
using WheelDeck.Core.Input;
using WheelDeck.Core.Output;
using WheelDeck.Core.Protocol;
using Xunit;

namespace WheelDeck.Tests;

public sealed class InputMapperTests
{
    private readonly FakeBackend _backend = new();
    private readonly InputMapper _mapper;

    public InputMapperTests()
    {
        _mapper = new InputMapper(_backend);
    }

    [Fact]
    public void ApplyState_SetsAllAxes()
    {
        var state = new StateMessage
        {
            Steering = 0.5,
            Accelerator = 0.8,
            Brake = 0.3,
            Clutch = 0.1
        };

        _mapper.ApplyState(state);

        Assert.Equal(0.5f, _backend.LastSteering);
        Assert.Equal(0.8f, _backend.LastAccelerator);
        Assert.Equal(0.3f, _backend.LastBrake);
        Assert.Equal(0.1f, _backend.LastClutch);
    }

    [Fact]
    public void ApplyState_ClampsSteeringToMinusOneToOne()
    {
        _mapper.ApplyState(new StateMessage { Steering = 5.0 });
        Assert.Equal(1.0f, _backend.LastSteering);

        _mapper.ApplyState(new StateMessage { Steering = -5.0 });
        Assert.Equal(-1.0f, _backend.LastSteering);
    }

    [Fact]
    public void ApplyState_ClampsPedalsToZeroToOne()
    {
        _mapper.ApplyState(new StateMessage { Accelerator = -0.5, Brake = 2.0, Clutch = 100.0 });
        Assert.Equal(0.0f, _backend.LastAccelerator);
        Assert.Equal(1.0f, _backend.LastBrake);
        Assert.Equal(1.0f, _backend.LastClutch);
    }

    [Fact]
    public void ApplyButton_SimulatedKeyPressMode_SendsKey()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ParkingBrake,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.Space, _backend.LastKeyCode);
        Assert.True(_backend.LastKeyPressed);
    }

    [Fact]
    public void ApplyButton_SimulatedKeyPressMode_ReleaseSendsKeyRelease()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ParkingBrake,
            Action = ActionType.Release
        });

        Assert.Equal(KeyCode.Space, _backend.LastKeyCode);
        Assert.False(_backend.LastKeyPressed);
    }

    [Fact]
    public void ApplyButton_SimulatedKeyPressMode_ToggleSendsPressThenRelease()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.TurnSignalLeft,
            Action = ActionType.Toggle
        });

        Assert.Equal(2, _backend.KeyEvents.Count);
        Assert.Equal((KeyCode.LeftBracket, true), _backend.KeyEvents[0]);
        Assert.Equal((KeyCode.LeftBracket, false), _backend.KeyEvents[1]);
    }

    [Fact]
    public void ApplyButton_ControllerButtonMode_SetsButton()
    {
        _mapper.Mode = MappingMode.ControllerButton;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ParkingBrake,
            Action = ActionType.Press
        });

        Assert.Equal(ButtonId.A, _backend.LastButtonId);
        Assert.True(_backend.LastButtonPressed);
    }

    [Fact]
    public void ApplyButton_ControllerButtonMode_TogglePressThenRelease()
    {
        _mapper.Mode = MappingMode.ControllerButton;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.CruiseToggle,
            Action = ActionType.Toggle
        });

        Assert.Equal(2, _backend.ButtonEvents.Count);
        Assert.Equal((ButtonId.LeftBumper, true), _backend.ButtonEvents[0]);
        Assert.Equal((ButtonId.LeftBumper, false), _backend.ButtonEvents[1]);
    }

    [Fact]
    public void ApplyButton_UnknownControl_IsIgnored()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = (ControlId)999,
            Action = ActionType.Press
        });

        Assert.Null(_backend.LastKeyCode);
    }

    [Fact]
    public void DefaultModeIsSimulatedKeyPress()
    {
        Assert.Equal(MappingMode.SimulatedKeyPress, _mapper.Mode);
    }

    [Fact]
    public void AllControlIds_HaveKeyBindingRows()
    {
        var keys = BindingTableKeys(typeof(InputMapper), "DefaultKeyBindings");
        Assert.Empty(Enum.GetValues<ControlId>().Except(keys));
    }

    [Fact]
    public void AllControlIds_HaveButtonBindingRows()
    {
        var buttons = BindingTableKeys(typeof(InputMapper), "DefaultButtonBindings");
        Assert.Empty(Enum.GetValues<ControlId>().Except(buttons));
    }

    [Fact]
    public void ComfortChatBatch_BindsResearchedKeys()
    {
        Assert.Equal(KeyCode.RightShift, KeyBindingFor(ControlId.DriverWindowUp));
        Assert.Equal(KeyCode.Slash, KeyBindingFor(ControlId.NavigationZoomIn));
        Assert.Equal(KeyCode.RightCtrl, KeyBindingFor(ControlId.DriverWindowDown));
        Assert.Equal(KeyCode.Comma, KeyBindingFor(ControlId.PassengerWindowUp));
        Assert.Equal(KeyCode.Dot, KeyBindingFor(ControlId.PassengerWindowDown));
        Assert.Equal(KeyCode.Tab, KeyBindingFor(ControlId.OverlayActivation));
        Assert.Equal(KeyCode.Y, KeyBindingFor(ControlId.ChatActivation));
        Assert.Equal(KeyCode.Q, KeyBindingFor(ControlId.QuickReplies));
        Assert.Equal(KeyCode.Z, KeyBindingFor(ControlId.NameTags));
        Assert.Equal(KeyCode.X, KeyBindingFor(ControlId.PushToTalk));
    }

    [Fact]
    public void AudioRow_UsesSequentialPresetKeys()
    {
        Assert.Equal(KeyCode.L, KeyBindingFor(ControlId.AudioVolumeDown));
        Assert.Equal(KeyCode.J, KeyBindingFor(ControlId.AudioPrevious));
        Assert.Equal(KeyCode.K, KeyBindingFor(ControlId.AudioPlayPause));
        Assert.Equal(KeyCode.U, KeyBindingFor(ControlId.AudioNext));
        Assert.Equal(KeyCode.O, KeyBindingFor(ControlId.AudioVolumeUp));
        // audioFavorite stays unbound; it has no researched key.
        Assert.Equal(KeyCode.None, KeyBindingFor(ControlId.AudioFavorite));
    }

    private KeyCode KeyBindingFor(ControlId control) =>
        (KeyCode)BindingTable(typeof(InputMapper), "DefaultKeyBindings")[control]!;

    private static System.Collections.IDictionary BindingTable(Type mapperType, string fieldName)
    {
        var field = mapperType.GetField(fieldName, BindingFlags.NonPublic | BindingFlags.Static);
        Assert.False(field is null, $"Expected private static table '{fieldName}' on InputMapper.");
        return (System.Collections.IDictionary)field!.GetValue(null)!;
    }

    private static HashSet<ControlId> BindingTableKeys(Type mapperType, string fieldName)
    {
        var table = BindingTable(mapperType, fieldName);
        var keys = new HashSet<ControlId>();
        foreach (ControlId control in table.Keys)
        {
            keys.Add(control);
        }

        return keys;
    }

    [Fact]
    public void ApplyButton_LightCycleIds_PulseHeadlightKey()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        foreach (var control in new[]
        {
            ControlId.LightsOff, ControlId.LightsParking, ControlId.LightsLowbeam
        })
        {
            _backend.Clear();
            _mapper.ApplyButton(new ButtonMessage
            {
                Control = control,
                Action = ActionType.Toggle
            });

            Assert.Equal(2, _backend.KeyEvents.Count);
            Assert.Equal((KeyCode.L, true), _backend.KeyEvents[0]);
            Assert.Equal((KeyCode.L, false), _backend.KeyEvents[1]);
        }
    }

    [Fact]
    public void ApplyButton_LightCycleIds_ControllerButtonMode_SetHeadlightButton()
    {
        _mapper.Mode = MappingMode.ControllerButton;

        foreach (var control in new[]
        {
            ControlId.LightsOff, ControlId.LightsParking, ControlId.LightsLowbeam
        })
        {
            _backend.Clear();
            _mapper.ApplyButton(new ButtonMessage
            {
                Control = control,
                Action = ActionType.Press
            });

            Assert.Equal(ButtonId.B, _backend.LastButtonId);
        }
    }

    [Fact]
    public void ApplyButton_NewToggleControl_PulsesItsKey()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.HazardLights,
            Action = ActionType.Toggle
        });

        Assert.Equal(2, _backend.KeyEvents.Count);
        Assert.Equal((KeyCode.F, true), _backend.KeyEvents[0]);
        Assert.Equal((KeyCode.F, false), _backend.KeyEvents[1]);
    }

    [Fact]
    public void ApplyButton_GearUp_SendsLeftShift()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.GearUp,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.LeftShift, _backend.LastKeyCode);
        Assert.True(_backend.LastKeyPressed);
    }

    [Fact]
    public void ApplyButton_NoneBoundControl_IsInertInBothModes()
    {
        // ShiftToDrive is None in both binding tables: the phone gates these.
        _mapper.Mode = MappingMode.SimulatedKeyPress;
        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ShiftToDrive,
            Action = ActionType.Press
        });
        Assert.Null(_backend.LastKeyCode);
        Assert.Null(_backend.LastButtonId);
        Assert.Empty(_backend.KeyEvents);
        Assert.Empty(_backend.ButtonEvents);

        _mapper.Mode = MappingMode.ControllerButton;
        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ShiftToDrive,
            Action = ActionType.Press
        });
        Assert.Null(_backend.LastKeyCode);
        Assert.Null(_backend.LastButtonId);
        Assert.Empty(_backend.KeyEvents);
        Assert.Empty(_backend.ButtonEvents);
    }

    [Fact]
    public void ApplyButton_ControllerButtonMode_DualBoundControl_FiresButtonNotKey()
    {
        _mapper.Mode = MappingMode.ControllerButton;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ParkingBrake,
            Action = ActionType.Press
        });

        Assert.Equal(ButtonId.A, _backend.LastButtonId);
        Assert.Null(_backend.LastKeyCode);
        Assert.Empty(_backend.KeyEvents);
    }

    [Fact]
    public void ApplyButton_ControllerButtonMode_KeyOnlyControl_FallsBackToKey()
    {
        _mapper.Mode = MappingMode.ControllerButton;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.BeaconLights,
            Action = ActionType.Toggle
        });

        Assert.Equal(2, _backend.KeyEvents.Count);
        Assert.Equal((KeyCode.O, true), _backend.KeyEvents[0]);
        Assert.Equal((KeyCode.O, false), _backend.KeyEvents[1]);
        Assert.Empty(_backend.ButtonEvents);
    }

    [Fact]
    public void ApplyButton_ControllerButtonMode_CameraPadControl_FallsBackToNumpadKey()
    {
        _mapper.Mode = MappingMode.ControllerButton;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.CameraPadUp,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.Numpad8, _backend.LastKeyCode);
        Assert.True(_backend.LastKeyPressed);
        Assert.Null(_backend.LastButtonId);
    }

    [Fact]
    public void ApplyButton_SimulatedKeyPressMode_DualBoundControl_FiresKeyNotButton()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ParkingBrake,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.Space, _backend.LastKeyCode);
        Assert.Null(_backend.LastButtonId);
        Assert.Empty(_backend.ButtonEvents);
    }

    [Fact]
    public void ApplyButton_ControllerButtonMode_NewControl_SetsSpareButton()
    {
        _mapper.Mode = MappingMode.ControllerButton;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.HazardLights,
            Action = ActionType.Press
        });

        Assert.Equal(ButtonId.Back, _backend.LastButtonId);
        Assert.True(_backend.LastButtonPressed);
    }

    [Fact]
    public void ActivePreset_DefaultsToSequential()
    {
        Assert.Equal(InputMapper.SequentialPreset, _mapper.ActivePreset);
    }

    [Fact]
    public void ApplyButton_PresetScopedLookup_SequentialUnchanged()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;
        _mapper.ActivePreset = "Sequential";

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ParkingBrake,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.Space, _backend.LastKeyCode);
        Assert.True(_backend.LastKeyPressed);
    }

    [Fact]
    public void ApplyButton_UnknownPreset_FallsBackToSequentialTables()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;
        _mapper.ActivePreset = "NoSuchPreset";

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ParkingBrake,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.Space, _backend.LastKeyCode);
        Assert.True(_backend.LastKeyPressed);
    }

    [Fact]
    public void ApplyButton_HybridPriority_HoldsUnderAnotherPreset()
    {
        _mapper.Mode = MappingMode.ControllerButton;
        _mapper.ActivePreset = "Real Automatic";

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.ParkingBrake,
            Action = ActionType.Press
        });

        Assert.Equal(ButtonId.A, _backend.LastButtonId);
        Assert.True(_backend.LastButtonPressed);
    }

    [Fact]
    public void ApplyButton_SimpleLeft_SendsNumpadDivide()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.CameraSimpleLeft,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.NumpadDivide, _backend.LastKeyCode);
        Assert.True(_backend.LastKeyPressed);
    }

    [Fact]
    public void ApplyButton_SimpleRight_SendsNumpadMultiply()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.CameraSimpleRight,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.NumpadMultiply, _backend.LastKeyCode);
        Assert.True(_backend.LastKeyPressed);
    }

    [Fact]
    public void ApplyButton_SimpleRecenter_SendsNumpad5()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        _mapper.ApplyButton(new ButtonMessage
        {
            Control = ControlId.CameraPadRecenter,
            Action = ActionType.Press
        });

        Assert.Equal(KeyCode.Numpad5, _backend.LastKeyCode);
        Assert.True(_backend.LastKeyPressed);
    }

    [Fact]
    public void ApplyState_RoutesCameraAxes()
    {
        _mapper.ApplyState(new StateMessage { CameraX = 0.5, CameraY = -0.5 });

        Assert.Equal(0.5f, _backend.LastCameraX);
        Assert.Equal(-0.5f, _backend.LastCameraY);
    }

    [Fact]
    public void ApplyState_ClampsCameraAxesToMinusOneToOne()
    {
        _mapper.ApplyState(new StateMessage { CameraX = 5.0, CameraY = -5.0 });

        Assert.Equal(1.0f, _backend.LastCameraX);
        Assert.Equal(-1.0f, _backend.LastCameraY);
    }

    private sealed class FakeBackend : VirtualOutputBackend
    {
        public float LastSteering { get; private set; }
        public float LastAccelerator { get; private set; }
        public float LastBrake { get; private set; }
        public float LastClutch { get; private set; }
        public float LastCameraX { get; private set; }
        public float LastCameraY { get; private set; }

        public KeyCode? LastKeyCode { get; private set; }
        public bool LastKeyPressed { get; private set; }
        public List<(KeyCode Key, bool Pressed)> KeyEvents { get; } = new();

        public ButtonId? LastButtonId { get; private set; }
        public bool LastButtonPressed { get; private set; }
        public List<(ButtonId Button, bool Pressed)> ButtonEvents { get; } = new();

        public int NeutralizeCount { get; private set; }

        public BackendResult Initialize() => BackendResult.Success();

        public void SetAxis(AxisType axis, float value)
        {
            switch (axis)
            {
                case AxisType.Steering: LastSteering = value; break;
                case AxisType.Accelerator: LastAccelerator = value; break;
                case AxisType.Brake: LastBrake = value; break;
                case AxisType.Clutch: LastClutch = value; break;
                case AxisType.CameraX: LastCameraX = value; break;
                case AxisType.CameraY: LastCameraY = value; break;
            }
        }

        public void SetButton(ButtonId button, bool pressed)
        {
            LastButtonId = button;
            LastButtonPressed = pressed;
            ButtonEvents.Add((button, pressed));
        }

        public void SendKey(KeyCode keyCode, bool pressed)
        {
            LastKeyCode = keyCode;
            LastKeyPressed = pressed;
            KeyEvents.Add((keyCode, pressed));
        }

        public void Neutralize() => NeutralizeCount++;

        public void Shutdown() { }

        public void Clear()
        {
            LastKeyCode = null;
            LastButtonId = null;
            KeyEvents.Clear();
            ButtonEvents.Clear();
        }
    }
}
