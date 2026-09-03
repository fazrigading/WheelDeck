namespace WheelDeck.Core.Output;

/// <summary>
/// OS-specific virtual output abstraction. Windows and Linux implement this interface
/// so the input mapper can drive a virtual controller without knowing which platform
/// it is running on. The composition root picks the concrete backend at startup.
/// </summary>
public interface VirtualOutputBackend
{
    /// <summary>Initializes the virtual device and returns success or a descriptive error.</summary>
    BackendResult Initialize();

    /// <summary>Sets an analog axis. Steering is -1.0..1.0; pedals are 0.0..1.0.</summary>
    void SetAxis(AxisType axis, float value);

    /// <summary>Sets a virtual-controller button state for controller-button mapping mode.</summary>
    void SetButton(ButtonId button, bool pressed);

    /// <summary>Sends a simulated key press or release for simulated-keypress mapping mode.</summary>
    void SendKey(KeyCode keyCode, bool pressed);

    /// <summary>Zeroes all axes and releases all buttons and keys.</summary>
    void Neutralize();

    /// <summary>Releases the virtual device and any native resources.</summary>
    void Shutdown();
}
