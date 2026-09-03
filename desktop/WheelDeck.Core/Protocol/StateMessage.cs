using System.Text.Json.Serialization;

namespace WheelDeck.Core.Protocol;

/// <summary>
/// Continuous steering and pedal state sent on every sensor or touch update.
/// Latest value wins; no acknowledgment required.
/// </summary>
public sealed record StateMessage
{
    [JsonPropertyName("type")]
    public string Type => "state";

    /// <summary>Monotonic sequence number used to detect and discard out-of-order packets.</summary>
    [JsonPropertyName("seq")]
    public long Seq { get; init; }

    /// <summary>Steering angle normalized to -1.0..1.0, where 0 is centered.</summary>
    [JsonPropertyName("steering")]
    public double Steering { get; init; }

    /// <summary>Accelerator pedal pressure, 0.0 at rest to 1.0 fully pressed.</summary>
    [JsonPropertyName("accelerator")]
    public double Accelerator { get; init; }

    /// <summary>Brake pedal pressure, 0.0 at rest to 1.0 fully pressed.</summary>
    [JsonPropertyName("brake")]
    public double Brake { get; init; }

    /// <summary>Clutch pedal pressure, 0.0 at rest to 1.0 fully pressed.</summary>
    [JsonPropertyName("clutch")]
    public double Clutch { get; init; }
}
