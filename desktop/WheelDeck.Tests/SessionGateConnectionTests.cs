using System.Net.WebSockets;
using WheelDeck.Core.Network;
using WheelDeck.Core.Pairing;
using WheelDeck.Core.Protocol;
using Xunit;

namespace WheelDeck.Tests;

public sealed class SessionGateConnectionTests
{
    [Fact]
    public void PairingCompleted_ReportsConnectedDevice()
    {
        var gate = new SessionGate(new PairingManager(), onState: _ => { }, onButton: _ => { });
        using var socket = new ClientWebSocket();
        var changes = 0;
        gate.ConnectionsChanged += () => changes++;

        gate.OnPairingCompleted(socket, "phone-1", "token");

        Assert.Equal(["phone-1"], gate.ConnectedDeviceIds);
        Assert.Equal(1, changes);
    }

    [Fact]
    public void RepeatHeartbeat_SignalsOnce()
    {
        var manager = new PairingManager();
        var token = manager.ValidatePairing("phone-1", manager.GeneratePairingCode().Code).SessionToken;
        manager.SetActiveDevice("phone-1");
        var gate = new SessionGate(manager, onState: _ => { }, onButton: _ => { });
        using var socket = new ClientWebSocket();
        var changes = 0;
        gate.ConnectionsChanged += () => changes++;

        gate.OnHeartbeat(new Heartbeat { SessionToken = token }, socket);
        gate.OnHeartbeat(new Heartbeat { SessionToken = token }, socket);

        Assert.Equal(["phone-1"], gate.ConnectedDeviceIds);
        Assert.Equal(1, changes);
    }

    [Fact]
    public void ConnectionClosed_ClearsConnectedDevice()
    {
        var gate = new SessionGate(new PairingManager(), onState: _ => { }, onButton: _ => { });
        using var socket = new ClientWebSocket();
        var changes = 0;
        gate.ConnectionsChanged += () => changes++;
        gate.OnPairingCompleted(socket, "phone-1", "token");

        gate.OnConnectionClosed(socket);

        Assert.Empty(gate.ConnectedDeviceIds);
        Assert.Equal(2, changes);
    }

    [Fact]
    public void UnknownSocketClose_StaysSilent()
    {
        var gate = new SessionGate(new PairingManager(), onState: _ => { }, onButton: _ => { });
        using var socket = new ClientWebSocket();
        var changes = 0;
        gate.ConnectionsChanged += () => changes++;

        gate.OnConnectionClosed(socket);

        Assert.Equal(0, changes);
    }
}
