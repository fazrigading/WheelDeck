using System.Text.Json.Serialization;

namespace WheelDeck.Core.Protocol;

/// <summary>
/// Desired dashboard input mapping sent by the phone (`keyboard` or `gamepad`).
/// Applied to the input mapper only when the sending connection is authorized.
/// </summary>
public sealed record MappingMessage
{
    [JsonPropertyName("type")]
    public string Type => "mapping";

    /// <summary>Either <c>"keyboard"</c> or <c>"gamepad"</c>. Unknown values keep the current mode.</summary>
    [JsonPropertyName("mode")]
    public string Mode { get; init; } = "keyboard";
}
