using System.Text.Json.Serialization;

namespace WheelDeck.Core.Protocol;

[JsonConverter(typeof(SnakeCaseEnumConverter<ActionType>))]
public enum ActionType
{
    Toggle,
    Press,
    Release,
    HoldConfirm
}
