using System.Text.Json;
using WheelDeck.Core.Protocol;
using Xunit;

namespace WheelDeck.Tests;

/// The desktop ControlId wire values must match protocol/schema/controls.json,
/// the shared contract both sides code against. Ticket #37.
public sealed class ControlIdContractTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    [Fact]
    public void ControlIdWireValues_MatchProtocolSchema()
    {
        var schemaFile = FindFile("protocol/schema/controls.json");
        using var doc = JsonDocument.Parse(File.ReadAllText(schemaFile));
        var expected = doc.RootElement
            .GetProperty("definitions")
            .GetProperty("ControlId")
            .GetProperty("enum")
            .EnumerateArray()
            .Select(e => e.GetString()!)
            .ToHashSet();

        var actual = Enum.GetValues<ControlId>()
            .Select(control =>
            {
                var msg = new ButtonMessage { Control = control, Action = ActionType.Press };
                using var json = JsonDocument.Parse(JsonSerializer.Serialize(msg, JsonOptions));
                return json.RootElement.GetProperty("control").GetString()!;
            })
            .ToHashSet();

        Assert.Equal(expected, actual);
    }

    private static string FindFile(string relativePath)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (var i = 0; i < 8 && dir is not null; i++)
        {
            var candidate = Path.Combine(dir.FullName, relativePath);
            if (File.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        throw new InvalidOperationException($"Could not locate {relativePath}.");
    }
}
