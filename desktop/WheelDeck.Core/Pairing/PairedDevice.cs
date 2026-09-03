namespace WheelDeck.Core.Pairing;

/// <summary>
/// A phone that has successfully paired with the desktop. Pairing persists until the
/// device is revoked or goes 30 days without being seen.
/// </summary>
public sealed record PairedDevice
{
    /// <summary>Stable identifier reported by the phone.</summary>
    public required string Id { get; init; }

    /// <summary>Human-friendly name shown in the desktop paired-device list.</summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>When this device first paired.</summary>
    public DateTimeOffset PairedAt { get; init; }

    /// <summary>Last time this device sent a heartbeat or re-paired.</summary>
    public DateTimeOffset LastSeenAt { get; set; }

    /// <summary>True when this is the device currently allowed to reach the input mapper.</summary>
    public bool IsActive { get; set; }
}
