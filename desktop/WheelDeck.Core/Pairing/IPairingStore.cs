namespace WheelDeck.Core.Pairing;

/// <summary>Loads and saves pairing state so pairings survive a desktop restart.</summary>
public interface IPairingStore
{
    /// <summary>Returns persisted state, or null when nothing has been saved yet.</summary>
    PairingState? Load();

    /// <summary>Persists the given pairing state.</summary>
    void Save(PairingState state);
}
