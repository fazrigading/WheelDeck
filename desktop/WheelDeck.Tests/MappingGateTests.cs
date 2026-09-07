using System.Net.WebSockets;
using WheelDeck.Core.Network;
using WheelDeck.Core.Pairing;
using WheelDeck.Core.Protocol;
using Xunit;

namespace WheelDeck.Tests;

public sealed class MappingGateTests
{
    [Fact]
    public void MappingMessageDeserializesFromJson()
    {
        var msg = System.Text.Json.JsonSerializer.Deserialize<MappingMessage>(
            """{"type":"mapping","mode":"gamepad"}""");

        Assert.NotNull(msg);
        Assert.Equal("gamepad", msg.Mode);
    }

    [Fact]
    public void AuthorizedMappingIsApplied()
    {
        var (gate, applied, socket, _) = BuildAuthorizedGate();

        gate.OnMapping(new MappingMessage { Mode = "gamepad" }, socket);

        Assert.Equal(["gamepad"], applied);
    }

    [Fact]
    public void UnauthorizedMappingIsIgnored()
    {
        var applied = new List<string>();
        var gate = new SessionGate(
            new PairingManager(),
            onState: _ => { },
            onButton: _ => { },
            onMapping: m => applied.Add(m.Mode));
        using var socket = new ClientWebSocket();

        gate.OnMapping(new MappingMessage { Mode = "gamepad" }, socket);

        Assert.Empty(applied);
    }

    [Fact]
    public void AdvertiserStartStopIsBestEffort()
    {
        using var advertiser = new MdnsAdvertiser();
        advertiser.Start();
        advertiser.Stop();
    }

    private static (SessionGate gate, List<string> applied, ClientWebSocket socket, PairingManager manager) BuildAuthorizedGate()
    {
        var manager = new PairingManager();
        var applied = new List<string>();
        var gate = new SessionGate(
            manager,
            onState: _ => { },
            onButton: _ => { },
            onMapping: m => applied.Add(m.Mode));

        var code = manager.GeneratePairingCode().Code;
        var result = manager.ValidatePairing("phone-1", code);
        Assert.True(result.Accepted);
        manager.SetActiveDevice("phone-1");

        var socket = new ClientWebSocket();
        gate.OnPairingCompleted(socket, "phone-1", result.SessionToken);
        return (gate, applied, socket, manager);
    }
}
