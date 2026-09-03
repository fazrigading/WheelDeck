using System.Text.Json;

namespace WheelDeck.Core.Pairing;

/// <summary>
/// JSON-file pairing store. Writes to a caller-supplied path so the composition root can
/// pick the OS-appropriate config location. Corrupt or missing files load as empty state.
/// </summary>
public sealed class JsonFilePairingStore : IPairingStore
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    private readonly string _path;

    public JsonFilePairingStore(string path)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);
        _path = path;
    }

    public PairingState? Load()
    {
        if (!File.Exists(_path))
        {
            return null;
        }

        try
        {
            return JsonSerializer.Deserialize<PairingState>(File.ReadAllText(_path), Options);
        }
        catch (JsonException)
        {
            return null;
        }
        catch (IOException)
        {
            return null;
        }
    }

    public void Save(PairingState state)
    {
        var directory = Path.GetDirectoryName(_path);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        File.WriteAllText(_path, JsonSerializer.Serialize(state, Options));
    }
}
