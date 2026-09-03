using System.Text.Json;
using System.Text.Json.Serialization;

namespace WheelDeck.Core.Protocol;

/// <summary>
/// Serializes enum members to the wire using snake_case, so PascalCase identifiers
/// like TurnSignalLeft become turn_signal_left on the wire.
/// </summary>
public sealed class SnakeCaseEnumConverter<T> : JsonConverter<T>
    where T : struct, Enum
{
    private static readonly JsonNamingPolicy Policy = JsonNamingPolicy.SnakeCaseLower;

    public override T Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        if (value is null)
        {
            throw new JsonException($"Null value for enum {typeof(T).Name}.");
        }

        foreach (var name in Enum.GetNames<T>())
        {
            if (Policy.ConvertName(name) == value)
            {
                return Enum.Parse<T>(name);
            }
        }

        throw new JsonException($"Unknown {typeof(T).Name} value '{value}'.");
    }

    public override void Write(Utf8JsonWriter writer, T value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(Policy.ConvertName(value.ToString()));
    }
}
