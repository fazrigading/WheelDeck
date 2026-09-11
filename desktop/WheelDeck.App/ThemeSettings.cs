using Avalonia.Styling;

namespace WheelDeck.App;

/// <summary>Persists the dark/light choice next to the pairing store. Missing or
/// unknown file content means follow the system theme.</summary>
public static class ThemeSettings
{
    private const string FileName = "theme.txt";

    public static ThemeVariant? Load(string? path = null)
    {
        string content;
        try
        {
            content = File.ReadAllText(path ?? DefaultPath()).Trim().ToLowerInvariant();
        }
        catch (IOException)
        {
            return null;
        }
        catch (UnauthorizedAccessException)
        {
            return null;
        }

        return content switch
        {
            "dark" => ThemeVariant.Dark,
            "light" => ThemeVariant.Light,
            _ => null,
        };
    }

    public static void Save(ThemeVariant? variant, string? path = null)
    {
        var file = path ?? DefaultPath();
        if (variant is null)
        {
            File.Delete(file);
            return;
        }

        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        var name = variant == ThemeVariant.Dark ? "dark" : "light";
        File.WriteAllText(file, name);
    }

    private static string DefaultPath() => Path.Combine(CompositionRoot.AppDataDirectory, FileName);
}
