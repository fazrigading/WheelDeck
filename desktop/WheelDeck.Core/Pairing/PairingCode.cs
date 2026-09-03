namespace WheelDeck.Core.Pairing;

/// <summary>A one-time pairing code the user enters or scans on the phone.</summary>
public sealed record PairingCode(string Code, DateTimeOffset ExpiresAt);
