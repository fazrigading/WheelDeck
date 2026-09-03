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
        var backend = CompositionRoot.CreateBackend();
        var result = backend.Initialize();

        if (result.IsSuccess)
        {
            backend.Shutdown();
            return new SetupResult(true, "Virtual output backend is ready.");
        }

        backend.Shutdown();

        var guidance = OperatingSystem.IsWindows()
            ? "ViGEmBus is not installed or not reachable. Install ViGEmBus and retry."
            : "uinput is not accessible. Install the udev rules (scripts/linux/install-uinput-rules.sh) and reload, then retry.";

        return new SetupResult(false, $"{result.Error}\n{guidance}");
    }
}
