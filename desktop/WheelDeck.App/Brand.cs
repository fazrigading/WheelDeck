using Avalonia;
using Avalonia.Media;
using Avalonia.Styling;

namespace WheelDeck.App;

/// <summary>Brand palette that follows the light/dark choice. The fixed navy chrome
/// never reacted to the theme toggle, so these resources are swapped in code and
/// referenced from AXAML via DynamicResource (which picks up the swap live).
/// Null choice means follow the system theme.</summary>
public static class Brand
{
    // Dark defaults (also the AXAML fallbacks) so static reads stay sane without an app.
    public static string StatusConnectedHex { get; private set; } = "#64FFDA";

    public static void Apply(ThemeVariant? choice)
    {
        var app = Application.Current;
        if (app is null)
        {
            return;
        }

        var dark = (choice ?? app.ActualThemeVariant) == ThemeVariant.Dark;

        Set("ChromeBackground", dark ? "#0A192F" : "#B4D4EE");
        Set("ChromeForeground", dark ? "#E6F1FF" : "#0A192F");
        Set("NavSelectedBackground", dark ? "#172A45" : "#3066BE");
        Set("NavSelectedForeground", dark ? "#E6F1FF" : "#F4F7F6");
        Set("AccentBrush", dark ? "#64FFDA" : "#3066BE");
        Set("AccentForeground", dark ? "#020C1B" : "#F4F7F6");
        Set("PageBackground", dark ? "#020C1B" : "#F4F7F6");
        Set("PageForeground", dark ? "#E6F1FF" : "#0A192F");
        Set("CardBackground", dark ? "#0A192F" : "#B4D4EE");
        Set("SecondaryText", dark ? "#B4D4EE" : "#172A45");

        StatusConnectedHex = dark ? "#64FFDA" : "#3066BE";

        void Set(string key, string hex) =>
            app.Resources[key] = new SolidColorBrush(Color.Parse(hex));
    }
}
