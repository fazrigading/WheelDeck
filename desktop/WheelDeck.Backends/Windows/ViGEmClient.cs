using System.Runtime.InteropServices;

namespace WheelDeck.Backends.Windows;

/// <summary>
/// Thin P/Invoke bindings to ViGEmClient.dll, the user-mode API for the ViGEmBus
/// virtual Xbox 360 controller driver. Handles are opaque pointers surfaced as IntPtr.
/// </summary>
internal static class ViGEmClient
{
    internal const string DllName = "ViGEmClient.dll";

    internal const int ErrorNone = 0x20000000;

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr vigem_alloc();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void vigem_free(IntPtr vigem);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int vigem_connect(IntPtr vigem);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void vigem_disconnect(IntPtr vigem);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr vigem_target_x360_alloc();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void vigem_target_free(IntPtr target);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int vigem_target_add(IntPtr vigem, IntPtr target);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int vigem_target_remove(IntPtr vigem, IntPtr target);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void vigem_target_set_vid(IntPtr target, ushort vid);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void vigem_target_set_pid(IntPtr target, ushort pid);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void vigem_target_x360_update(IntPtr vigem, IntPtr target, XUsbReport report);
}

/// <summary>
/// Xbox 360 gamepad report, byte-identical to XINPUT_GAMEPAD. Trims the vendor union
/// wrapper to just the fields the backend writes.
/// </summary>
[StructLayout(LayoutKind.Sequential)]
internal struct XUsbReport
{
    public ushort Buttons;
    public byte LeftTrigger;
    public byte RightTrigger;
    public short ThumbLX;
    public short ThumbLY;
    public short ThumbRX;
    public short ThumbRY;

    public static XUsbReport Neutral() => new();
}
