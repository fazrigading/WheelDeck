using HIDMaestro;
using WheelDeck.Core.Output;

namespace WheelDeck.Backends.Windows;

/// <summary>
/// Windows virtual output backend. Exposes analog axes and controller buttons through
/// HIDMaestro (user-mode UMDF2 driver, Xbox 360 wired profile), and simulates keyboard
/// presses through the SendInput API.
/// </summary>
public sealed class HidMaestroBackend : VirtualOutputBackend
{
    private const ushort VendorId = 0x045E;  // Microsoft
    private const ushort ProductId = 0x028E; // Xbox 360 Controller for Windows
    private const string ProfileId = "xbox-360-wired";

    private static readonly IReadOnlyDictionary<ButtonId, HMButton> ButtonMasks =
        new Dictionary<ButtonId, HMButton>
        {
            [ButtonId.A] = HMButton.A,
            [ButtonId.B] = HMButton.B,
            [ButtonId.X] = HMButton.X,
            [ButtonId.Y] = HMButton.Y,
            [ButtonId.LeftBumper] = HMButton.LeftBumper,
            [ButtonId.RightBumper] = HMButton.RightBumper,
            [ButtonId.Back] = HMButton.Back,
            [ButtonId.Start] = HMButton.Start,
            [ButtonId.LeftThumb] = HMButton.LeftStick,
            [ButtonId.RightThumb] = HMButton.RightStick,
            [ButtonId.Guide] = HMButton.Guide
        };

    private static readonly IReadOnlyDictionary<ButtonId, HMHat> HatMasks =
        new Dictionary<ButtonId, HMHat>
        {
            [ButtonId.DPadUp] = HMHat.North,
            [ButtonId.DPadDown] = HMHat.South,
            [ButtonId.DPadLeft] = HMHat.West,
            [ButtonId.DPadRight] = HMHat.East
        };

    private readonly object _lock = new();
    private readonly SendInputKeySimulator _keys = new();

    private HMContext? _context;
    private HMController? _controller;

    private float _steering;
    private float _accelerator;
    private float _brake;
    private float _clutch;
    private HMButton _buttons;
    private readonly HashSet<ButtonId> _pressedHatButtons = new();

    public BackendResult Initialize()
    {
        lock (_lock)
        {
            if (_controller is not null)
            {
                return BackendResult.Success();
            }

            HMOemNameOverride.RecoverOrphans();

            var context = new HMContext();
            try
            {
                context.LoadDefaultProfiles();

                try
                {
                    context.InstallDriver();
                }
                catch (UnauthorizedAccessException)
                {
                    context.Dispose();
                    return BackendResult.Failure(
                        "HIDMaestro driver install requires administrator privileges. Run as administrator and retry.");
                }
                catch (InvalidOperationException ex)
                {
                    context.Dispose();
                    return BackendResult.Failure($"HIDMaestro driver install failed: {ex.Message}");
                }

                var profile = context.GetProfile(ProfileId);
                if (profile is null)
                {
                    context.Dispose();
                    return BackendResult.Failure($"HIDMaestro profile '{ProfileId}' not found.");
                }

                if (profile.VendorId != VendorId || profile.ProductId != ProductId)
                {
                    context.Dispose();
                    return BackendResult.Failure(
                        $"HIDMaestro profile '{ProfileId}' has unexpected identity " +
                        $"VID 0x{profile.VendorId:X4} PID 0x{profile.ProductId:X4}; " +
                        $"expected VID 0x{VendorId:X4} PID 0x{ProductId:X4}.");
                }

                _context = context;
                _controller = context.CreateController(profile);

                _steering = 0f;
                _accelerator = 0f;
                _brake = 0f;
                _clutch = 0f;
                _buttons = HMButton.None;
                _pressedHatButtons.Clear();

                Update();

                return BackendResult.Success();
            }
            catch (Exception ex) when (ex is not UnauthorizedAccessException and not InvalidOperationException)
            {
                _controller = null;
                _context = null;
                context.Dispose();
                return BackendResult.Failure($"Failed to initialize HIDMaestro backend: {ex.Message}");
            }
        }
    }

    public void SetAxis(AxisType axis, float value)
    {
        lock (_lock)
        {
            EnsureInitialized();

            switch (axis)
            {
                case AxisType.Steering:
                    _steering = Math.Clamp(value, -1f, 1f);
                    break;
                case AxisType.Accelerator:
                    _accelerator = Math.Clamp(value, 0f, 1f);
                    break;
                case AxisType.Brake:
                    _brake = Math.Clamp(value, 0f, 1f);
                    break;
                case AxisType.Clutch:
                    _clutch = Math.Clamp(value, 0f, 1f);
                    break;
            }

            Update();
        }
    }

    public void SetButton(ButtonId button, bool pressed)
    {
        lock (_lock)
        {
            EnsureInitialized();

            if (ButtonMasks.TryGetValue(button, out var mask))
            {
                if (pressed)
                {
                    _buttons |= mask;
                }
                else
                {
                    _buttons &= ~mask;
                }

                Update();
                return;
            }

            if (HatMasks.ContainsKey(button))
            {
                if (pressed)
                {
                    _pressedHatButtons.Add(button);
                }
                else
                {
                    _pressedHatButtons.Remove(button);
                }

                Update();
            }
        }
    }

    public void SendKey(KeyCode keyCode, bool pressed)
    {
        lock (_lock)
        {
            if (pressed)
            {
                _keys.Press(keyCode);
            }
            else
            {
                _keys.Release(keyCode);
            }
        }
    }

    public void Neutralize()
    {
        lock (_lock)
        {
            EnsureInitialized();

            _steering = 0f;
            _accelerator = 0f;
            _brake = 0f;
            _clutch = 0f;
            _buttons = HMButton.None;
            _pressedHatButtons.Clear();
            _keys.ReleaseAll();

            Update();
        }
    }

    public void Shutdown()
    {
        lock (_lock)
        {
            if (_controller is null)
            {
                return;
            }

            NeutralizeLocked();

            _controller.Dispose();
            _controller = null;

            _context?.Dispose();
            _context = null;

            _keys.Dispose();
        }
    }

    private void NeutralizeLocked()
    {
        _steering = 0f;
        _accelerator = 0f;
        _brake = 0f;
        _clutch = 0f;
        _buttons = HMButton.None;
        _pressedHatButtons.Clear();
        _keys.ReleaseAll();
        Update();
    }

    private void EnsureInitialized()
    {
        if (_controller is null)
        {
            throw new InvalidOperationException("The HIDMaestro backend is not initialized.");
        }
    }

    private void Update()
    {
        if (_controller is null)
        {
            return;
        }

        var state = new HMGamepadState
        {
            Axes = HMGamepadStateHelpers.StandardAxes(
                _controller.Profile,
                leftStickX: (_steering + 1f) / 2f,
                leftStickY: (_clutch + 1f) / 2f,
                leftTrigger: _accelerator,
                rightTrigger: _brake),
            Buttons = _buttons,
            Hat = ResolveHat()
        };

        _controller.SubmitState(in state);
    }

    private HMHat ResolveHat()
    {
        var up = _pressedHatButtons.Contains(ButtonId.DPadUp);
        var down = _pressedHatButtons.Contains(ButtonId.DPadDown);
        var left = _pressedHatButtons.Contains(ButtonId.DPadLeft);
        var right = _pressedHatButtons.Contains(ButtonId.DPadRight);

        return (up, down, left, right) switch
        {
            (true, false, false, false) => HMHat.North,
            (true, false, true, false) => HMHat.NorthWest,
            (true, false, false, true) => HMHat.NorthEast,
            (false, true, false, false) => HMHat.South,
            (false, true, true, false) => HMHat.SouthWest,
            (false, true, false, true) => HMHat.SouthEast,
            (false, false, true, false) => HMHat.West,
            (false, false, false, true) => HMHat.East,
            _ => HMHat.None
        };
    }
}
