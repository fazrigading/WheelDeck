using Avalonia;
using Avalonia.Controls;

namespace WheelDeck.App;

/// <summary>Opens URLs in the system browser. Fire-and-forget: a failed launch does nothing.</summary>
public static class Browser
{
    public static async void Open(string url, Visual visual)
    {
        try
        {
            var launcher = TopLevel.GetTopLevel(visual)?.Launcher;
            if (launcher is not null)
            {
                await launcher.LaunchUriAsync(new Uri(url));
            }
        }
        catch (Exception)
        {
            // No browser or no desktop session; the button just does nothing.
        }
    }
}
