using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using WheelDeck.Core.Pairing;
using WheelDeck.Core.Protocol;

namespace WheelDeck.Core.Network;

/// <summary>
/// Handles the pair_request/pair_response flow over the WebSocket listener. On a
/// successful pairing it issues a session token and replies to the phone.
/// </summary>
public sealed class PairingService
{
    private static readonly JsonSerializerOptions Options = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };

    private readonly PairingManager _pairingManager;

    public event Action<WebSocket, string, string?>? PairingCompleted;

    public PairingService(PairingManager pairingManager)
    {
        _pairingManager = pairingManager;
    }

    public void Handle(PairRequest request, WebSocket socket)
    {
        var result = _pairingManager.ValidatePairing(request.DeviceId, request.Code);

        var response = new PairResponse
        {
            DeviceId = request.DeviceId,
            Accepted = result.Accepted,
            SessionToken = result.SessionToken
        };

        if (result.Accepted)
        {
            PairingCompleted?.Invoke(socket, request.DeviceId, result.SessionToken);
        }

        SendAsync(socket, response);
    }

    private static async void SendAsync(WebSocket socket, PairResponse response)
    {
        try
        {
            var json = JsonSerializer.Serialize(response, Options);
            var bytes = Encoding.UTF8.GetBytes(json);
            await socket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
        }
        catch (WebSocketException)
        {
            // The phone disconnected before the response could be sent.
        }
    }
}
