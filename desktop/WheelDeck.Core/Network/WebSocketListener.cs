using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using WheelDeck.Core.Protocol;

namespace WheelDeck.Core.Network;

/// <summary>
/// Accepts WebSocket connections and dispatches parsed state and button messages.
/// The pairing gate and heartbeat handling sit on top of this transport in the
/// session layer; this class only frames and deserializes inbound messages.
/// </summary>
public sealed class WebSocketListener : IAsyncDisposable
{
    public const int DefaultPort = 8765;

    private readonly HttpListener _httpListener = new();
    private readonly int _port;
    private CancellationTokenSource? _cts;

    public event Action<StateMessage>? StateReceived;
    public event Action<ButtonMessage>? ButtonReceived;

    public WebSocketListener(int port = DefaultPort)
    {
        _port = port;
    }

    /// <summary>Starts listening on all interfaces. Throws if the port is unavailable.</summary>
    public Task StartAsync(CancellationToken ct = default)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        _httpListener.Prefixes.Add($"http://+:{_port}/");
        _httpListener.Start();

        _ = Task.Run(() => AcceptLoopAsync(_cts.Token), CancellationToken.None);

        return Task.CompletedTask;
    }

    /// <summary>Stops accepting connections and releases the underlying socket.</summary>
    public void Stop()
    {
        _cts?.Cancel();
        _httpListener.Stop();
        _httpListener.Close();
    }

    public ValueTask DisposeAsync()
    {
        Stop();
        return ValueTask.CompletedTask;
    }

    private async Task AcceptLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            HttpListenerContext context;
            try
            {
                context = await _httpListener.GetContextAsync().ConfigureAwait(false);
            }
            catch (Exception) when (ct.IsCancellationRequested || _httpListener is null)
            {
                break;
            }

            if (!context.Request.IsWebSocketRequest)
            {
                context.Response.StatusCode = 400;
                context.Response.Close();
                continue;
            }

            _ = Task.Run(() => HandleClientAsync(context, ct), CancellationToken.None);
        }
    }

    private async Task HandleClientAsync(HttpListenerContext context, CancellationToken ct)
    {
        WebSocket? socket = null;
        try
        {
            var wsContext = await context.AcceptWebSocketAsync(null).ConfigureAwait(false);
            socket = wsContext.WebSocket;
            await ReceiveLoopAsync(socket, ct).ConfigureAwait(false);
        }
        catch (Exception)
        {
            // A dropped client must not take down the listener.
        }
        finally
        {
            socket?.Dispose();
        }
    }

    private async Task ReceiveLoopAsync(WebSocket socket, CancellationToken ct)
    {
        var buffer = new byte[4096];
        var message = new MemoryStream();

        while (socket.State == WebSocketState.Open && !ct.IsCancellationRequested)
        {
            WebSocketReceiveResult result;
            try
            {
                result = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), ct).ConfigureAwait(false);
            }
            catch (WebSocketException)
            {
                break;
            }

            if (result.MessageType == WebSocketMessageType.Close)
            {
                await socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "close", ct).ConfigureAwait(false);
                break;
            }

            message.Write(buffer, 0, result.Count);

            if (result.EndOfMessage)
            {
                var text = Encoding.UTF8.GetString(message.ToArray());
                message.SetLength(0);
                Dispatch(text);
            }
        }
    }

    private void Dispatch(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var type = doc.RootElement.GetProperty("type").GetString();

            switch (type)
            {
                case "state":
                    var state = JsonSerializer.Deserialize<StateMessage>(json);
                    if (state is not null)
                    {
                        StateReceived?.Invoke(state);
                    }

                    break;

                case "button":
                    var button = JsonSerializer.Deserialize<ButtonMessage>(json);
                    if (button is not null)
                    {
                        ButtonReceived?.Invoke(button);
                    }

                    break;
            }
        }
        catch (JsonException)
        {
            // Ignore malformed frames; they never reach the input mapper.
        }
    }
}
