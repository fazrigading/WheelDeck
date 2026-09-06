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
    public void AllControlIds_HaveKeyBindings()
    {
        _mapper.Mode = MappingMode.SimulatedKeyPress;

        foreach (var control in Enum.GetValues<ControlId>())
        {
            _backend.Clear();
            _mapper.ApplyButton(new ButtonMessage
            {
                Control = control,
                Action = ActionType.Press
            });

            Assert.NotNull(_backend.LastKeyCode);
        }
    }

    [Fact]
    public void AllControlIds_HaveButtonBindings()
    {
        _mapper.Mode = MappingMode.ControllerButton;

        foreach (var control in Enum.GetValues<ControlId>())
        {
            _backend.Clear();
            _mapper.ApplyButton(new ButtonMessage
            {
                Control = control,
                Action = ActionType.Press
            });

            Assert.NotNull(_backend.LastButtonId);
        }
    }

    private sealed class FakeBackend : VirtualOutputBackend
    {
        public float LastSteering { get; private set; }
        public float LastAccelerator { get; private set; }
        public float LastBrake { get; private set; }
        public float LastClutch { get; private set; }

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
