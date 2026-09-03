namespace WheelDeck.Core.Pairing;

/// <summary>
/// A snapshot of pairing state suitable for persisting across sessions. Contains the
/// paired devices and the session-token to device-id mapping.
/// </summary>
public sealed class PairingState
{
    public List<PairedDevice> Devices { get; set; } = new();

    public Dictionary<string, string> SessionTokens { get; set; } = new();
}
