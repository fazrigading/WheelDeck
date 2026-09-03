using WheelDeck.Core.Output;
using WheelDeck.Core.Protocol;

namespace WheelDeck.Core.Network;

/// <summary>
/// Watches inbound heartbeats and neutralizes the virtual output when a configured
/// number of beats are missed. The desktop sends no heartbeats itself in v1; it only
/// reacts to the phone's ~2s beats.
/// </summary>
public sealed class HeartbeatMonitor : IAsyncDisposable
{
    private static readonly TimeSpan BeatInterval = TimeSpan.FromSeconds(2);

    private readonly VirtualOutputBackend _backend;
    private readonly int _missedBeatLimit;
    private readonly Func<DateTimeOffset> _now;

    private DateTimeOffset _lastBeat;
    private bool _running;
    private CancellationTokenSource? _cts;

    public HeartbeatMonitor(VirtualOutputBackend backend, int missedBeatLimit = 2, Func<DateTimeOffset>? now = null)
    {
        _backend = backend;
        _missedBeatLimit = missedBeatLimit;
        _now = now ?? (() => DateTimeOffset.UtcNow);
        _lastBeat = _now();
    }

    /// <summary>Resets the timeout on every heartbeat received from the phone.</summary>
    public void OnHeartbeat(Heartbeat heartbeat)
    {
        _lastBeat = _now();
    }

    /// <summary>Starts the background watchdog loop.</summary>
    public void Start()
    {
        if (_running)
        {
            return;
        }

        _running = true;
        _lastBeat = _now();
        _cts = new CancellationTokenSource();
        _ = Task.Run(() => WatchAsync(_cts.Token), CancellationToken.None);
    }

    public void Stop()
    {
        _running = false;
        _cts?.Cancel();
    }

    public ValueTask DisposeAsync()
    {
        Stop();
        return ValueTask.CompletedTask;
    }

    private async Task WatchAsync(CancellationToken ct)
    {
        while (_running && !ct.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(BeatInterval, ct).ConfigureAwait(false);
            }
            catch (TaskCanceledException)
            {
                break;
            }

            var elapsed = _now() - _lastBeat;
            if (elapsed >= BeatInterval * (_missedBeatLimit + 1))
            {
                _backend.Neutralize();
            }
        }
    }
}
