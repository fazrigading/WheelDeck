using HIDMaestro;
using WheelDeck.Core.Output;

namespace WheelDeck.App;

/// <summary>
/// Runs the first-run setup check by attempting to initialize the platform backend and
/// surfacing a plain-language result with remediation guidance.
/// </summary>
public sealed class SetupChecker
{
    /// <summary>Outcome of a setup check, including what to do when it fails.</summary>
    public sealed record SetupResult(bool IsReady, string Message);

    public SetupResult Check()
    {
        if (OperatingSystem.IsWindows())
        {
            var driverError = EnsureHidMaestroDriver();
            if (driverError is not null)
            {
                return new SetupResult(false, driverError);
            }
        }

        var backend = CompositionRoot.CreateBackend();
        var result = backend.Initialize();

        if (result.IsSuccess)
        {
            backend.Shutdown();
            return new SetupResult(true, "Virtual output backend is ready.");
        }

        backend.Shutdown();

        var guidance = OperatingSystem.IsWindows()
            ? "HIDMaestro driver is not installed or not reachable. The driver installs automatically on first use (administrator required). If installation fails, run as administrator and retry."
            : "uinput is not accessible. Install the udev rules (scripts/linux/install-uinput-rules.sh) and reload, then retry.";

        return new SetupResult(false, $"{result.Error}\n{guidance}");
    }

    /// <summary>
    /// Ensures the HIDMaestro driver is installed before the backend initializes.
    /// Returns null on success, or a plain-language error message on failure.
    /// </summary>
    public static string? EnsureHidMaestroDriver()
    {
        try
        {
            using var context = new HMContext();
            context.LoadDefaultProfiles();
            context.InstallDriver();
            return null;
        }
        catch (UnauthorizedAccessException)
        {
            return "HIDMaestro driver install requires administrator privileges. Run as administrator and retry.";
        }
        catch (InvalidOperationException ex)
        {
            return $"HIDMaestro driver install failed: {ex.Message} Run as administrator and retry.";
        }
    }
}
