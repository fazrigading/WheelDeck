using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using WheelDeck.Core.Output;

namespace WheelDeck.Backends.Linux;

/// <summary>
/// Linux uinput virtual joystick backend. Exposes analog axes, joystick buttons, and
/// synthetic key events so the desktop can present a virtual controller and simulate
/// keyboard presses. Requires the udev uinput rules from scripts/linux to be installed.
/// </summary>
public sealed class UinputBackend : VirtualOutputBackend
{
    private const string DevicePath = "/dev/uinput";
    private const string FallbackDevicePath = "/dev/input/uinput";

    private const int OWriteOnly = 0x0001;
    private const int ONonBlock = 0x0800;

    private const ushort EvSyn = 0x00;
    private const ushort EvKey = 0x01;
    private const ushort EvAbs = 0x03;
    private const ushort SynReport = 0x00;

    private const ushort BusVirtual = 0x06;

    private const ulong UiSetEvBit = 0x40045564;
    private const ulong UiSetKeyBit = 0x40045565;
    private const ulong UiSetAbsBit = 0x40045567;
    private const ulong UiDevSetup = 0x405C5503;
    private const ulong UiAbsSetup = 0x401C5504;
    private const ulong UiDevCreate = 0x5501;
    private const ulong UiDevDestroy = 0x5502;

    private const short AxisMinimum = -32768;
    private const short AxisMaximum = 32767;

    private static readonly IReadOnlyDictionary<AxisType, ushort> AxisCodes =
        new Dictionary<AxisType, ushort>
        {
            [AxisType.Steering] = 0x00,    // ABS_X
            [AxisType.Accelerator] = 0x01, // ABS_Y
            [AxisType.Brake] = 0x02,       // ABS_Z
            [AxisType.Clutch] = 0x05       // ABS_RZ
        };

    private static readonly IReadOnlyDictionary<ButtonId, ushort> ButtonCodes =
        new Dictionary<ButtonId, ushort>
        {
            [ButtonId.A] = 0x120,            // BTN_JOYSTICK
            [ButtonId.B] = 0x121,            // BTN_THUMB
            [ButtonId.X] = 0x122,            // BTN_THUMB2
            [ButtonId.Y] = 0x123,            // BTN_TOP
            [ButtonId.LeftBumper] = 0x124,   // BTN_TOP2
            [ButtonId.RightBumper] = 0x125,  // BTN_PINKIE
            [ButtonId.Back] = 0x126,         // BTN_BASE
            [ButtonId.Start] = 0x127,        // BTN_BASE2
            [ButtonId.LeftThumb] = 0x128,    // BTN_BASE3
            [ButtonId.RightThumb] = 0x129,   // BTN_BASE4
            [ButtonId.DPadUp] = 0x12a,       // BTN_BASE5
            [ButtonId.DPadDown] = 0x12b,     // BTN_BASE6
            [ButtonId.DPadLeft] = 0x2c0,     // BTN_TRIGGER_HAPPY1
            [ButtonId.DPadRight] = 0x2c1,    // BTN_TRIGGER_HAPPY2
            [ButtonId.Guide] = 0x12f         // BTN_DEAD
        };

    private static readonly IReadOnlyDictionary<KeyCode, ushort> KeyCodes =
        new Dictionary<KeyCode, ushort>
        {
            [KeyCode.A] = 30, [KeyCode.B] = 48, [KeyCode.C] = 46, [KeyCode.D] = 32,
            [KeyCode.E] = 18, [KeyCode.F] = 33, [KeyCode.G] = 34, [KeyCode.H] = 35,
            [KeyCode.I] = 23, [KeyCode.J] = 36, [KeyCode.K] = 37, [KeyCode.L] = 38,
            [KeyCode.M] = 50, [KeyCode.N] = 49, [KeyCode.O] = 24, [KeyCode.P] = 25,
            [KeyCode.Q] = 16, [KeyCode.R] = 19, [KeyCode.S] = 31, [KeyCode.T] = 20,
            [KeyCode.U] = 22, [KeyCode.V] = 47, [KeyCode.W] = 17, [KeyCode.X] = 45,
            [KeyCode.Y] = 21, [KeyCode.Z] = 44,
            [KeyCode.Space] = 57,             // KEY_SPACE
            [KeyCode.LeftBracket] = 26,       // KEY_LEFTBRACE
            [KeyCode.RightBracket] = 27,      // KEY_RIGHTBRACE
            [KeyCode.Enter] = 28,             // KEY_ENTER
            [KeyCode.Escape] = 1              // KEY_ESC
        };

    private static readonly int InputEventSize = Marshal.SizeOf<InputEvent>();

    private readonly object _lock = new();
    private readonly HashSet<ButtonId> _pressedButtons = new();
    private readonly HashSet<KeyCode> _pressedKeys = new();

    private int _fd = -1;

    public BackendResult Initialize()
    {
        lock (_lock)
        {
            if (_fd >= 0)
            {
                return BackendResult.Success();
            }

            var fd = open(DevicePath, OWriteOnly | ONonBlock);
            if (fd < 0)
            {
                fd = open(FallbackDevicePath, OWriteOnly | ONonBlock);
            }

            if (fd < 0)
            {
                return BackendResult.Failure($"Unable to open uinput device: {LastError()}");
            }

            try
            {
                EnableEventType(fd, EvKey);
                EnableEventType(fd, EvAbs);

                foreach (var code in ButtonCodes.Values.Concat(KeyCodes.Values))
                {
                    SetBit(fd, UiSetKeyBit, code);
                }

                foreach (var (axis, code) in AxisCodes)
                {
                    SetBit(fd, UiSetAbsBit, code);
                    var minimum = axis == AxisType.Steering ? AxisMinimum : 0;
                    ConfigureAbsAxis(fd, code, minimum, AxisMaximum);
                }

                SetupDevice(fd);
                CreateDevice(fd);
            }
            catch (IOException ex)
            {
                close(fd);
                return BackendResult.Failure(ex.Message);
            }

            _fd = fd;
            _pressedButtons.Clear();
            _pressedKeys.Clear();

            return BackendResult.Success();
        }
    }

    public void SetAxis(AxisType axis, float value)
    {
        if (!AxisCodes.TryGetValue(axis, out var code))
        {
            return;
        }

        lock (_lock)
        {
            EnsureInitialized();
            WriteEvent(EvAbs, code, NormalizeAxis(axis, value));
            WriteSync();
        }
    }

    public void SetButton(ButtonId button, bool pressed)
    {
        if (!ButtonCodes.TryGetValue(button, out var code))
        {
            return;
        }

        lock (_lock)
        {
            EnsureInitialized();
            WriteEvent(EvKey, code, pressed ? 1 : 0);
            WriteSync();

            if (pressed)
            {
                _pressedButtons.Add(button);
            }
            else
            {
                _pressedButtons.Remove(button);
            }
        }
    }

    public void SendKey(KeyCode keyCode, bool pressed)
    {
        if (!KeyCodes.TryGetValue(keyCode, out var code))
        {
            return;
        }

        lock (_lock)
        {
            EnsureInitialized();
            WriteEvent(EvKey, code, pressed ? 1 : 0);
            WriteSync();

            if (pressed)
            {
                _pressedKeys.Add(keyCode);
            }
            else
            {
                _pressedKeys.Remove(keyCode);
            }
        }
    }

    public void Neutralize()
    {
        lock (_lock)
        {
            EnsureInitialized();

            foreach (var code in AxisCodes.Values)
            {
                WriteEvent(EvAbs, code, 0);
            }

            foreach (var button in _pressedButtons.ToArray())
            {
                if (ButtonCodes.TryGetValue(button, out var code))
                {
                    WriteEvent(EvKey, code, 0);
                }
            }

            foreach (var key in _pressedKeys.ToArray())
            {
                if (KeyCodes.TryGetValue(key, out var code))
                {
                    WriteEvent(EvKey, code, 0);
                }
            }

            WriteSync();

            _pressedButtons.Clear();
            _pressedKeys.Clear();
        }
    }

    public void Shutdown()
    {
        lock (_lock)
        {
            if (_fd < 0)
            {
                return;
            }

            NeutralizeLocked();
            ioctl(_fd, UiDevDestroy);
            close(_fd);
            _fd = -1;
        }
    }

    private void NeutralizeLocked()
    {
        foreach (var code in AxisCodes.Values)
        {
            WriteEvent(EvAbs, code, 0);
        }

        foreach (var button in _pressedButtons)
        {
            if (ButtonCodes.TryGetValue(button, out var code))
            {
                WriteEvent(EvKey, code, 0);
            }
        }

        foreach (var key in _pressedKeys)
        {
            if (KeyCodes.TryGetValue(key, out var code))
            {
                WriteEvent(EvKey, code, 0);
            }
        }

        WriteSync();
        _pressedButtons.Clear();
        _pressedKeys.Clear();
    }

    private void EnsureInitialized()
    {
        if (_fd < 0)
        {
            throw new InvalidOperationException("The uinput backend is not initialized.");
        }
    }

    private static int NormalizeAxis(AxisType axis, float value)
    {
        if (axis == AxisType.Steering)
        {
            return (int)MathF.Round(Math.Clamp(value, -1f, 1f) * AxisMaximum);
        }

        return (int)MathF.Round(Math.Clamp(value, 0f, 1f) * AxisMaximum);
    }

    private void WriteSync() => WriteEvent(EvSyn, SynReport, 0);

    private void WriteEvent(ushort type, ushort code, int value)
    {
        var ev = new InputEvent
        {
            time = default,
            type = type,
            code = code,
            value = value
        };

        if (write(_fd, ref ev, (nuint)InputEventSize) < 0)
        {
            throw new IOException($"Failed to write uinput event: {LastError()}");
        }
    }

    private static void EnableEventType(int fd, ushort type)
    {
        if (ioctl(fd, UiSetEvBit, (ulong)type) < 0)
        {
            throw new IOException($"Failed to enable event type: {LastError()}");
        }
    }

    private static void SetBit(int fd, ulong request, ushort bit)
    {
        if (ioctl(fd, request, (ulong)bit) < 0)
        {
            throw new IOException($"Failed to set uinput bit: {LastError()}");
        }
    }

    private static void ConfigureAbsAxis(int fd, ushort code, int minimum, int maximum)
    {
        var setup = new UInputAbsSetup
        {
            code = code,
            absinfo = new InputAbsInfo
            {
                value = 0,
                minimum = minimum,
                maximum = maximum,
                fuzz = 0,
                flat = 0,
                resolution = 0
            }
        };

        if (ioctl(fd, UiAbsSetup, ref setup) < 0)
        {
            throw new IOException($"Failed to configure absolute axis: {LastError()}");
        }
    }

    private static void SetupDevice(int fd)
    {
        var setup = new UInputSetup
        {
            id = new InputId
            {
                bustype = BusVirtual,
                vendor = 0x1234,
                product = 0x5678,
                version = 1
            },
            name = new byte[80],
            ffEffectsMax = 0
        };

        var name = Encoding.UTF8.GetBytes("WheelDeck Virtual Joystick");
        Array.Copy(name, setup.name, Math.Min(name.Length, setup.name.Length - 1));

        if (ioctl(fd, UiDevSetup, ref setup) < 0)
        {
            throw new IOException($"Failed to configure uinput device: {LastError()}");
        }
    }

    private static void CreateDevice(int fd)
    {
        if (ioctl(fd, UiDevCreate) < 0)
        {
            throw new IOException($"Failed to create uinput device: {LastError()}");
        }
    }

    private static string LastError() => new System.ComponentModel.Win32Exception(Marshal.GetLastPInvokeError()).Message;

    [DllImport("libc", SetLastError = true)]
    private static extern int open([MarshalAs(UnmanagedType.LPStr)] string pathname, int flags);

    [DllImport("libc", SetLastError = true)]
    private static extern int close(int fd);

    [DllImport("libc", SetLastError = true)]
    private static extern int ioctl(int fd, ulong request);

    [DllImport("libc", SetLastError = true)]
    private static extern int ioctl(int fd, ulong request, ulong value);

    [DllImport("libc", SetLastError = true)]
    private static extern int ioctl(int fd, ulong request, ref UInputAbsSetup setup);

    [DllImport("libc", SetLastError = true)]
    private static extern int ioctl(int fd, ulong request, ref UInputSetup setup);

    [DllImport("libc", SetLastError = true)]
    private static extern long write(int fd, ref InputEvent ev, nuint count);

    [StructLayout(LayoutKind.Sequential)]
    private struct Timeval
    {
        public long tvSec;
        public long tvUsec;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct InputEvent
    {
        public Timeval time;
        public ushort type;
        public ushort code;
        public int value;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct InputId
    {
        public ushort bustype;
        public ushort vendor;
        public ushort product;
        public ushort version;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct InputAbsInfo
    {
        public int value;
        public int minimum;
        public int maximum;
        public int fuzz;
        public int flat;
        public int resolution;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct UInputAbsSetup
    {
        public ushort code;
        public InputAbsInfo absinfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct UInputSetup
    {
        public InputId id;

        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 80)]
        public byte[] name;

        public uint ffEffectsMax;
    }
}
