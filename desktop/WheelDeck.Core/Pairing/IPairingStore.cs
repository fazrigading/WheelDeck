namespace WheelDeck.Core.Pairing;

/// <summary>Loads and saves paired devices so pairings survive a desktop restart.</summary>
public interface IPairingStore
{
    /// <summary>Returns persisted devices, or null when nothing has been saved yet.</summary>
    IReadOnlyList<PairedDevice>? Load();

    /// <summary>Persists the given paired devices.</summary>
    void Save(IReadOnlyList<PairedDevice> devices);
}
