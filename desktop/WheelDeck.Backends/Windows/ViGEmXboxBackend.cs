using WheelDeck.Core.Output;

namespace WheelDeck.Backends.Windows;

/// <summary>
/// Windows virtual output backend. Exposes analog axes and controller buttons through
/// ViGEmBus, and simulates keyboard presses through the SendInput API.
/// </summary>
public sealed class ViGEmXboxBackend : VirtualOutputBackend
{
    private const ushort VendorId = 0x045E;  // Microsoft
    private const ushort ProductId = 0x028E; // Xbox 360 Controller for Windows

    private const ushort ButtonUp = 0x0001;
    private const ushort ButtonDown = 0x0002;
    private const ushort ButtonLeft = 0x0004;
    private const ushort ButtonRight = 0x0008;
    private const ushort ButtonStart = 0x0010;
    private const ushort ButtonBack = 0x0020;
    private const ushort ButtonLeftThumb = 0x0040;
    private const ushort ButtonRightThumb = 0x0080;
    private const ushort ButtonLeftBumper = 0x0100;
    private const ushort ButtonRightBumper = 0x0200;
    private const ushort ButtonGuide = 0x0400;
    private const ushort ButtonA = 0x1000;
    private const ushort ButtonB = 0x2000;
    private const ushort ButtonX = 0x4000;
    private const ushort ButtonY = 0x8000;

    private const short AxisMinimum = short.MinValue;
    private const short AxisMaximum = short.MaxValue;

    private static readonly IReadOnlyDictionary<ButtonId, ushort> ButtonMasks =
        new Dictionary<ButtonId, ushort>
        {
            [ButtonId.A] = ButtonA,
            [ButtonId.B] = ButtonB,
            [ButtonId.X] = ButtonX,
            [ButtonId.Y] = ButtonY,
            [ButtonId.LeftBumper] = ButtonLeftBumper,
            [ButtonId.RightBumper] = ButtonRightBumper,
            [ButtonId.Back] = ButtonBack,
            [ButtonId.Start] = ButtonStart,
            [ButtonId.LeftThumb] = ButtonLeftThumb,
            [ButtonId.RightThumb] = ButtonRightThumb,
            [ButtonId.DPadUp] = ButtonUp,
            [ButtonId.DPadDown] = ButtonDown,
            [ButtonId.DPadLeft] = ButtonLeft,
            [ButtonId.DPadRight] = ButtonRight,
            [ButtonId.Guide] = ButtonGuide
        };

    private readonly object _lock = new();
    private readonly SendInputKeySimulator _keys = new();

    private IntPtr _vigem = IntPtr.Zero;
    private IntPtr _target = IntPtr.Zero;

    private float _steering;
    private float _accelerator;
    private float _brake;
    private float _clutch;
    private ushort _buttons;

    public BackendResult Initialize()
    {
        lock (_lock)
        {
            if (_target != IntPtr.Zero)
            {
                return BackendResult.Success();
            }

            _vigem = ViGEmClient.vigem_alloc();
            if (_vigem == IntPtr.Zero)
            {
                return BackendResult.Failure("Failed to allocate ViGEmBus client.");
            }

            if (ViGEmClient.vigem_connect(_vigem) != ViGEmClient.ErrorNone)
            {
                ViGEmClient.vigem_free(_vigem);
                _vigem = IntPtr.Zero;
                return BackendResult.Failure("Failed to connect to ViGEmBus. Is the driver installed?");
            }

            _target = ViGEmClient.vigem_target_x360_alloc();
            if (_target == IntPtr.Zero)
            {
                ViGEmClient.vigem_disconnect(_vigem);
                ViGEmClient.vigem_free(_vigem);
                _vigem = IntPtr.Zero;
                return BackendResult.Failure("Failed to allocate Xbox 360 target.");
            }

            ViGEmClient.vigem_target_set_vid(_target, VendorId);
            ViGEmClient.vigem_target_set_pid(_target, ProductId);

            if (ViGEmClient.vigem_target_add(_vigem, _target) != ViGEmClient.ErrorNone)
            {
                ViGEmClient.vigem_target_free(_target);
                ViGEmClient.vigem_disconnect(_vigem);
                ViGEmClient.vigem_free(_vigem);
                _vigem = IntPtr.Zero;
                _target = IntPtr.Zero;
                return BackendResult.Failure("Failed to register Xbox 360 target with ViGEmBus.");
            }

            _steering = 0f;
            _accelerator = 0f;
            _brake = 0f;
            _clutch = 0f;
            _buttons = 0;

            Update();

            return BackendResult.Success();
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
        if (!ButtonMasks.TryGetValue(button, out var mask))
        {
            return;
        }

        lock (_lock)
        {
            EnsureInitialized();

            if (pressed)
            {
                _buttons |= mask;
            }
            else
            {
                _buttons &= (ushort)~mask;
            }

            Update();
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
            _buttons = 0;
            _keys.ReleaseAll();

            Update();
        }
    }

    public void Shutdown()
    {
        lock (_lock)
        {
            if (_vigem == IntPtr.Zero)
            {
                return;
            }

            NeutralizeLocked();

            if (_target != IntPtr.Zero)
            {
                ViGEmClient.vigem_target_remove(_vigem, _target);
                ViGEmClient.vigem_target_free(_target);
                _target = IntPtr.Zero;
            }

            ViGEmClient.vigem_disconnect(_vigem);
            ViGEmClient.vigem_free(_vigem);
            _vigem = IntPtr.Zero;

            _keys.Dispose();
        }
    }

    private void NeutralizeLocked()
    {
        _steering = 0f;
        _accelerator = 0f;
        _brake = 0f;
        _clutch = 0f;
        _buttons = 0;
        _keys.ReleaseAll();
        Update();
    }

    private void EnsureInitialized()
    {
        if (_target == IntPtr.Zero)
        {
            throw new InvalidOperationException("The ViGEmBus backend is not initialized.");
        }
    }

    private void Update()
    {
        var report = new XUsbReport
        {
            Buttons = _buttons,
            LeftTrigger = ToTrigger(_accelerator),
            RightTrigger = ToTrigger(_brake),
            ThumbLX = ToAxis(_steering),
            ThumbLY = ToAxis(_clutch),
            ThumbRX = 0,
            ThumbRY = 0
        };

        ViGEmClient.vigem_target_x360_update(_vigem, _target, report);
    }

    private static byte ToTrigger(float value) => (byte)MathF.Round(Math.Clamp(value, 0f, 1f) * byte.MaxValue);

    private static short ToAxis(float value) => (short)MathF.Round(Math.Clamp(value, -1f, 1f) * AxisMaximum);
}
