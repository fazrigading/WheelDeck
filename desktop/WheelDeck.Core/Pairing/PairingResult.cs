namespace WheelDeck.Core.Pairing;

/// <summary>Result of validating a pairing request.</summary>
public sealed record PairingResult(bool Accepted, string? SessionToken = null);
