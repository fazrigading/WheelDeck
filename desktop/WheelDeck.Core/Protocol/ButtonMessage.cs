using System.Text.Json.Serialization;

namespace WheelDeck.Core.Protocol;

/// <summary>Discrete dashboard control event. Delivered reliably over TCP.</summary>
public sealed record ButtonMessage
{
    [JsonPropertyName("type")]
    public string Type => "button";

    [JsonPropertyName("control")]
    public ControlId Control { get; init; }

    [JsonPropertyName("action")]
    public ActionType Action { get; init; }
}
