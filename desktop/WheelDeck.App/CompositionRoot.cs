using System.Runtime.InteropServices;
using WheelDeck.Backends.Linux;
using WheelDeck.Backends.Windows;
using WheelDeck.Core.Input;
using WheelDeck.Core.Network;
using WheelDeck.Core.Output;
using WheelDeck.Core.Pairing;

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
            onConnectionClosed: _ => Backend.Neutralize());

        Listener = new WebSocketListener(port);
        HeartbeatMonitor = new HeartbeatMonitor(Backend);

        Listener.StateReceived += (state, socket) => _gate.OnState(state, socket);
        Listener.ButtonReceived += (button, socket) => _gate.OnButton(button, socket);
        Listener.PairRequestReceived += (request, socket) => PairingService.Handle(request, socket);
        Listener.HeartbeatReceived += (heartbeat, socket) => _gate.OnHeartbeat(heartbeat, socket);
        Listener.ConnectionClosed += _gate.OnConnectionClosed;

        PairingService.PairingCompleted += (socket, deviceId, _) => _gate.OnPairingCompleted(socket, deviceId, _);
        _gate.HeartbeatAccepted += HeartbeatMonitor.OnHeartbeat;
    }

    public void Start(CancellationToken ct = default)
    {
        Backend.Initialize();
        HeartbeatMonitor.Start();
        Listener.StartAsync(ct);
    }

    public async Task StopAsync()
    {
        Listener.Stop();
        await HeartbeatMonitor.DisposeAsync();
        Backend.Neutralize();
        Backend.Shutdown();
    }

    private static VirtualOutputBackend CreateBackend()
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
