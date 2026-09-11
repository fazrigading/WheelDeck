using Avalonia.Styling;
using WheelDeck.App.ViewModels;
using Xunit;

namespace WheelDeck.Tests;

public sealed class SettingsViewModelTests
{
    [Fact]
    public void SetTheme_AppliesAndPersistsChoice()
    {
        var current = (ThemeVariant?)null;
        var applied = new List<ThemeVariant?>();
        var vm = new SettingsViewModel(() => current, v => { current = v; applied.Add(v); }, "Listening on port 8765");

        Assert.Equal("System", vm.ThemeLabel);

        vm.UseDarkThemeCommand.Execute(null);

        Assert.Equal([ThemeVariant.Dark], applied);
        Assert.Equal("Dark", vm.ThemeLabel);

        vm.UseSystemThemeCommand.Execute(null);

        Assert.Equal([ThemeVariant.Dark, null], applied);
        Assert.Equal("System", vm.ThemeLabel);
    }

    [Fact]
    public void PortInfo_Passthrough()
    {
        var vm = new SettingsViewModel(() => null, _ => { }, "Listening on port 8765");

        Assert.Equal("Listening on port 8765", vm.PortInfo);
    }
}
