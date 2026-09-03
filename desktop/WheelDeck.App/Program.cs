using Avalonia;
using WheelDeck.App;

namespace WheelDeck.App;

internal static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (args.Contains("--daemon", StringComparer.OrdinalIgnoreCase))
        {
            return RunDaemon();
        }

        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
        return 0;
    }

    public static AppBuilder BuildAvaloniaApp() =>
        AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace();

    private static int RunDaemon()
    {
        Console.WriteLine("WheelDeck daemon starting. Press Ctrl+C to stop.");

        var root = new CompositionRoot();
        root.Start();

        using var shutdown = new ManualResetEventSlim(false);
        Console.CancelKeyPress += (_, e) =>
        {
            e.Cancel = true;
            shutdown.Set();
        };

        shutdown.Wait();
        root.StopAsync().GetAwaiter().GetResult();

        Console.WriteLine("WheelDeck daemon stopped.");
        return 0;
    }
}
