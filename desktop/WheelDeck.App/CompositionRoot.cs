using System.Net.WebSockets;
using System.Runtime.InteropServices;
using System.Text;
using WheelDeck.Backends.Linux;
using WheelDeck.Backends.Windows;
using WheelDeck.Core.Input;
using WheelDeck.Core.Network;
using WheelDeck.Core.Output;
using WheelDeck.Core.Pairing;
using WheelDeck.Core.Protocol;

namespace WheelDeck.App;

/// <summary>
/// Wires the desktop server together. Picks the virtual output backend for the running
/// OS, then composes the input mapper, session gate, pairing flow, heartbeat monitor,
/// and WebSocket listener into a single startable server.
/// </summary>
public sealed class CompositionRoot
{
    public VirtualOutputBackend Backend { get; }
    public InputMapper InputMapper { get; }
    public PairingManager PairingManager { get; }
    public PairingService PairingService { get; }
    public WebSocketListener Listener { get; }
    public HeartbeatMonitor HeartbeatMonitor { get; }
    public MdnsAdvertiser Advertiser { get; }

    /// <summary>Session gate, exposed so the shell can show live connection state.</summary>
    public SessionGate Gate => _gate;

    private readonly SessionGate _gate;

    public CompositionRoot(int port = WebSocketListener.DefaultPort, IPairingStore? pairingStore = null)
    {
        Backend = CreateBackend();
        InputMapper = new InputMapper(Backend);
        PairingManager = new PairingManager(pairingStore ?? CreatePairingStore());
        PairingService = new PairingService(PairingManager);

        _gate = new SessionGate(
            PairingManager,
            onState: InputMapper.ApplyState,
            onButton: InputMapper.ApplyButton,
            onConnectionClosed: _ => Backend.Neutralize(),
            onMapping: ApplyMapping);

        Listener = new WebSocketListener(port);
        HeartbeatMonitor = new HeartbeatMonitor(Backend);
        Advertiser = new MdnsAdvertiser(port);

        Listener.StateReceived += (state, socket) => _gate.OnState(state, socket);
        Listener.ButtonReceived += (button, socket) => _gate.OnButton(button, socket);
        Listener.MappingReceived += (mapping, socket) => _gate.OnMapping(mapping, socket);
        Listener.PairRequestReceived += (request, socket) => PairingService.Handle(request, socket);
        Listener.HeartbeatReceived += (heartbeat, socket) => _gate.OnHeartbeat(heartbeat, socket);
        Listener.ConnectionClosed += _gate.OnConnectionClosed;

        PairingService.PairingCompleted += (socket, deviceId, _) => _gate.OnPairingCompleted(socket, deviceId, _);
        _gate.HeartbeatAccepted += HeartbeatMonitor.OnHeartbeat;
        _gate.UnknownSessionToken += RejectStaleSession;
    }

    public void Start(CancellationToken ct = default)
    {
        Backend.Initialize();
        HeartbeatMonitor.Start();
        Advertiser.Start();
        Listener.StartAsync(ct);
    }

    public async Task StopAsync()
    {
        Advertiser.Stop();
        Listener.Stop();
        await HeartbeatMonitor.DisposeAsync();
        Backend.Neutralize();
        Backend.Shutdown();
    }

    /// <summary>Applies the phone's dashboard mapping choice to the input mapper.</summary>
    private void ApplyMapping(MappingMessage mapping)
    {
        InputMapper.Mode = mapping.Mode.Equals("gamepad", StringComparison.OrdinalIgnoreCase)
            ? MappingMode.ControllerButton
            : MappingMode.SimulatedKeyPress;
    }

    /// <summary>Tells a phone with a stale token to re-pair. Fire-and-forget:
    /// a dropped socket just means the phone already reconnected.</summary>
    private static async void RejectStaleSession(WebSocket socket)
    {
        try
        {
            var json = """{"type":"pair_response","accepted":false}""";
            var bytes = Encoding.UTF8.GetBytes(json);
            await socket.SendAsync(
                new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
        }
        catch (Exception)
        {
            // Socket already gone; the next heartbeat on the new socket retries.
        }
    }

    /// <summary>Creates the virtual output backend for the current OS. Public for the setup check.</summary>
    public static VirtualOutputBackend CreateBackend()
    {
        if (OperatingSystem.IsWindows())
        {
            return new ViGEmXboxBackend();
        }

        if (OperatingSystem.IsLinux())
        {
            return new UinputBackend();
        }

        throw new PlatformNotSupportedException("WheelDeck supports Windows and Linux only.");
    }

    private static IPairingStore CreatePairingStore()
    {
        var baseDir = OperatingSystem.IsWindows()
            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WheelDeck")
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".config", "wheeldeck");

        return new JsonFilePairingStore(Path.Combine(baseDir, "pairings.json"));
    }
}
