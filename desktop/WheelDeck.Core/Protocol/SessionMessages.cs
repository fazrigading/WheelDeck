using System.Text.Json.Serialization;

namespace WheelDeck.Core.Protocol;

/// <summary>Phone requests pairing, including the entered PIN or scanned QR token.</summary>
public sealed record PairRequest
{
    [JsonPropertyName("type")]
    public string Type => "pair_request";

    /// <summary>Stable identifier for the phone requesting pairing.</summary>
    [JsonPropertyName("device_id")]
    public string DeviceId { get; init; } = string.Empty;

    /// <summary>The PIN or scanned QR token entered on the phone.</summary>
    [JsonPropertyName("code")]
    public string Code { get; init; } = string.Empty;
}

/// <summary>Desktop accepts or rejects a pairing request.</summary>
public sealed record PairResponse
{
    [JsonPropertyName("type")]
    public string Type => "pair_response";

    [JsonPropertyName("device_id")]
    public string DeviceId { get; init; } = string.Empty;

    /// <summary>True when the pairing code matched and the device is now paired.</summary>
    [JsonPropertyName("accepted")]
    public bool Accepted { get; init; }

    /// <summary>Issued on accepted pairing; lets the phone skip re-pairing on later sessions.</summary>
    [JsonPropertyName("session_token")]
    public string? SessionToken { get; init; }
}

/// <summary>Sent every ~2s by both sides to keep the session alive.</summary>
public sealed record Heartbeat
{
    [JsonPropertyName("type")]
    public string Type => "heartbeat";

    /// <summary>Optional token identifying the sending device on an active session.</summary>
    [JsonPropertyName("session_token")]
    public string? SessionToken { get; init; }
}

/// <summary>Desktop tells a phone it is no longer the active device.</summary>
public sealed record DeviceSwitch
{
    [JsonPropertyName("type")]
    public string Type => "device_switch";

    /// <summary>Identifier of the device that is no longer active.</summary>
    [JsonPropertyName("device_id")]
    public string? DeviceId { get; init; }
}
