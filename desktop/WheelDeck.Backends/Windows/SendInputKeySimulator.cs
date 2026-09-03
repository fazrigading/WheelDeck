using System.Runtime.InteropServices;
using WheelDeck.Core.Output;

namespace WheelDeck.Backends.Windows;

/// <summary>
/// Simulates keyboard input using the Windows SendInput API. Tracks held keys so a
/// release can target exactly what was pressed.
/// </summary>
public sealed class SendInputKeySimulator : IDisposable
{
    private const uint InputKeyboard = 1;
    private const uint KeyEventExtendedKey = 0x0001;
    private const uint KeyEventKeyUp = 0x0002;

    private static readonly IReadOnlyDictionary<KeyCode, ushort> VirtualKeyCodes =
        new Dictionary<KeyCode, ushort>
        {
            [KeyCode.A] = 0x41, [KeyCode.B] = 0x42, [KeyCode.C] = 0x43, [KeyCode.D] = 0x44,
            [KeyCode.E] = 0x45, [KeyCode.F] = 0x46, [KeyCode.G] = 0x47, [KeyCode.H] = 0x48,
            [KeyCode.I] = 0x49, [KeyCode.J] = 0x4A, [KeyCode.K] = 0x4B, [KeyCode.L] = 0x4C,
            [KeyCode.M] = 0x4D, [KeyCode.N] = 0x4E, [KeyCode.O] = 0x4F, [KeyCode.P] = 0x50,
            [KeyCode.Q] = 0x51, [KeyCode.R] = 0x52, [KeyCode.S] = 0x53, [KeyCode.T] = 0x54,
            [KeyCode.U] = 0x55, [KeyCode.V] = 0x56, [KeyCode.W] = 0x57, [KeyCode.X] = 0x58,
            [KeyCode.Y] = 0x59, [KeyCode.Z] = 0x5A,
            [KeyCode.Space] = 0x20,          // VK_SPACE
            [KeyCode.LeftBracket] = 0xDB,    // VK_OEM_4
            [KeyCode.RightBracket] = 0xDD,   // VK_OEM_6
            [KeyCode.Enter] = 0x0D,          // VK_RETURN
            [KeyCode.Escape] = 0x1B          // VK_ESCAPE
        };

    private readonly HashSet<KeyCode> _pressed = new();

    public void Press(KeyCode keyCode)
    {
        if (keyCode == KeyCode.None || !VirtualKeyCodes.TryGetValue(keyCode, out var vk))
        {
            return;
        }

        if (_pressed.Add(keyCode))
        {
            SendKeyEvent(vk, false);
        }
    }

    public void Release(KeyCode keyCode)
    {
        if (keyCode == KeyCode.None || !VirtualKeyCodes.TryGetValue(keyCode, out var vk))
        {
            return;
        }

        if (_pressed.Remove(keyCode))
        {
            SendKeyEvent(vk, true);
        }
    }

    public void ReleaseAll()
    {
        foreach (var key in _pressed.ToArray())
        {
            if (VirtualKeyCodes.TryGetValue(key, out var vk))
            {
                SendKeyEvent(vk, true);
            }
        }

        _pressed.Clear();
    }

    public void Dispose() => ReleaseAll();

    private static void SendKeyEvent(ushort virtualKey, bool keyUp)
    {
        var input = new INPUT
        {
            type = InputKeyboard,
            union = new InputUnion
            {
                keyboard = new KeyboardInput
                {
                    wVk = virtualKey,
                    wScan = 0,
                    dwFlags = keyUp ? KeyEventKeyUp : 0
                }
            }
        };

        if (SendInput(1, ref input, Marshal.SizeOf<INPUT>()) == 0)
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastPInvokeError());
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion union;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)]
        public KeyboardInput keyboard;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardInput
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public nuint dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint inputCount, ref INPUT input, int size);
}
