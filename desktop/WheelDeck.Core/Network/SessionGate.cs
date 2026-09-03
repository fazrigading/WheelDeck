using System.Net.WebSockets;
using WheelDeck.Core.Pairing;
using WheelDeck.Core.Protocol;

namespace WheelDeck.Core.Network;

/// <summary>
/// Single enforcement point for the public-network safety rule: no state or button
/// message reaches the input mapper unless it comes from the currently active,
/// non-expired, non-revoked device. Each socket is bound to a device by a heartbeat
/// session token or by a successful pairing, then authorized on every forwarded input.
/// </summary>
public sealed class SessionGate
{
    private readonly PairingManager _pairingManager;
    private readonly Action<StateMessage> _onState;
    private readonly Action<ButtonMessage> _onButton;
    private readonly Action<WebSocket> _onConnectionClosed;
    private readonly Dictionary<WebSocket, string?> _connectionDevices = new();

    /// <summary>Fires when an authorized device sends a heartbeat, so the monitor can reset.</summary>
    public event Action<Heartbeat>? HeartbeatAccepted;

    public SessionGate(
        PairingManager pairingManager,
        Action<StateMessage> onState,
        Action<ButtonMessage> onButton,
        Action<WebSocket>? onConnectionClosed = null)
    {
        _pairingManager = pairingManager;
        _onState = onState;
        _onButton = onButton;
        _onConnectionClosed = onConnectionClosed ?? (_ => { });
    }

    /// <summary>Binds a connection to a device after a successful pairing.</summary>
    public void OnPairingCompleted(WebSocket socket, string deviceId, string? sessionToken)
    {
        _connectionDevices[socket] = deviceId;
    }

    /// <summary>Updates the last-seen timestamp and binds the connection via its token.</summary>
    public void OnHeartbeat(Heartbeat heartbeat, WebSocket socket)
    {
        var device = ResolveDevice(heartbeat.SessionToken);
        if (device is null)
        {
            return;
        }

        _pairingManager.TouchLastSeen(device.Id);
        _connectionDevices[socket] = device.Id;
        HeartbeatAccepted?.Invoke(heartbeat);
    }

    /// <summary>Forwards a state message only when the sending connection is authorized.</summary>
    public void OnState(StateMessage state, WebSocket socket)
    {
        if (IsAuthorized(socket))
        {
            _onState(state);
        }
    }

    /// <summary>Forwards a button message only when the sending connection is authorized.</summary>
    public void OnButton(ButtonMessage button, WebSocket socket)
    {
        if (IsAuthorized(socket))
        {
            _onButton(button);
        }
    }

    /// <summary>Forgets a connection when it drops.</summary>
    public void OnConnectionClosed(WebSocket socket)
    {
        _connectionDevices.Remove(socket);
        _onConnectionClosed(socket);
    }

    private bool IsAuthorized(WebSocket socket)
    {
        if (!_connectionDevices.TryGetValue(socket, out var deviceId) || deviceId is null)
        {
            return false;
        }

        return _pairingManager.IsAuthorized(FindDeviceById(deviceId));
    }

    private PairedDevice? ResolveDevice(string? sessionToken) =>
        sessionToken is null ? null : _pairingManager.FindDeviceBySessionToken(sessionToken);

    private PairedDevice? FindDeviceById(string deviceId) =>
        _pairingManager.ListPairedDevices().FirstOrDefault(d => d.Id == deviceId);
}
