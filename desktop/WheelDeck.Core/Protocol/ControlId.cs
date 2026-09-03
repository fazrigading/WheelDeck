using System.Text.Json.Serialization;

namespace WheelDeck.Core.Protocol;

[JsonConverter(typeof(SnakeCaseEnumConverter<ControlId>))]
public enum ControlId
{
    ParkingBrake,
    TurnSignalLeft,
    TurnSignalRight,
    HeadlightToggle,
    HighBeamToggle,
    Wipers,
    CruiseToggle,
    CruiseSetResume,
    EngineStart
}
