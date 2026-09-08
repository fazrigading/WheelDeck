using System.Net.WebSockets;
using WheelDeck.Core.Network;
using WheelDeck.Core.Pairing;
using WheelDeck.Core.Protocol;
using Xunit;

namespace WheelDeck.Tests;

public sealed class MappingGateTests
{
    private static readonly DateTimeOffset FixedNow = new(2026, 9, 3, 12, 0, 0, TimeSpan.Zero);

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

    [Fact]
    public void SessionTokenSurvivesReload()
    {
        var store = new InMemoryPairingStore();
        var first = new PairingManager(store, () => FixedNow);
        var token = first.ValidatePairing("phone-1", first.GeneratePairingCode().Code).SessionToken;
        first.SetActiveDevice("phone-1");

        // Simulate a desktop restart: a fresh manager over the same store.
        var second = new PairingManager(store, () => FixedNow);
        var device = second.FindDeviceBySessionToken(token!);

        Assert.NotNull(device);
        Assert.Equal("phone-1", device.Id);
        Assert.True(second.IsAuthorized(device));
    }

    [Fact]
    public void HeartbeatBindsAfterRestart()
    {
        var store = new InMemoryPairingStore();
        var first = new PairingManager(store, () => FixedNow);
        var token = first.ValidatePairing("phone-1", first.GeneratePairingCode().Code).SessionToken;
        first.SetActiveDevice("phone-1");

        var second = new PairingManager(store, () => FixedNow);
        var states = 0;
        var gate = new SessionGate(
            second,
            onState: _ => states++,
            onButton: _ => { });
        using var socket = new ClientWebSocket();

        gate.OnHeartbeat(new Heartbeat { SessionToken = token }, socket);
        gate.OnState(
            new StateMessage { Seq = 1, Steering = 0.5, Accelerator = 0, Brake = 0, Clutch = 0 },
            socket);

        Assert.Equal(1, states);
    }

    [Fact]
    public void UnknownTokenSignalsOncePerConnection()
    {
        var gate = new SessionGate(
            new PairingManager(),
            onState: _ => { },
            onButton: _ => { });
        using var socket = new ClientWebSocket();
        var signals = 0;
        gate.UnknownSessionToken += _ => signals++;

        gate.OnHeartbeat(new Heartbeat { SessionToken = "stale" }, socket);
        gate.OnHeartbeat(new Heartbeat { SessionToken = "stale" }, socket);

        Assert.Equal(1, signals);
    }

    [Fact]
    public void TokenlessHeartbeatStaysSilent()
    {
        var gate = new SessionGate(
            new PairingManager(),
            onState: _ => { },
            onButton: _ => { });
        using var socket = new ClientWebSocket();
        var signals = 0;
        gate.UnknownSessionToken += _ => signals++;

        gate.OnHeartbeat(new Heartbeat(), socket);

        Assert.Equal(0, signals);
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
