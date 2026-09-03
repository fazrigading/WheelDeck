using WheelDeck.Core.Pairing;

namespace WheelDeck.Tests;

/// <summary>In-memory store that keeps the last saved devices for test assertions.</summary>
internal sealed class InMemoryPairingStore : IPairingStore
{
    public IReadOnlyList<PairedDevice>? Saved { get; private set; }

    public IReadOnlyList<PairedDevice>? Load() => Saved;

    public void Save(IReadOnlyList<PairedDevice> devices) => Saved = devices.ToList();
}
