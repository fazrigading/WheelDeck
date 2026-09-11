using WheelDeck.App.ViewModels;
using WheelDeck.Core.Pairing;
using Xunit;

namespace WheelDeck.Tests;

public sealed class ConnectionViewModelTests
{
    [Fact]
    public void Connected_ShowsDeviceName()
    {
        var vm = new ConnectionViewModel();

        vm.UpdateFrom(ManagerWithActiveDevice(), isRunning: true, port: 8765, connectedDeviceIds: ["phone-1"]);

        Assert.Equal("Connected to phone-1", vm.StatusText);
        Assert.True(vm.IsDeviceConnected);
        Assert.Equal("#3DA35D", vm.StatusColor);
        Assert.Equal("phone-1", vm.PairedDevice);
    }

    [Fact]
    public void Idle_ShowsListening()
    {
        var vm = new ConnectionViewModel();

        vm.UpdateFrom(ManagerWithActiveDevice(), isRunning: true, port: 8765, connectedDeviceIds: []);

        Assert.Equal("Listening on port 8765", vm.StatusText);
        Assert.False(vm.IsDeviceConnected);
        Assert.Equal("#8A8A8A", vm.StatusColor);
        Assert.Equal("phone-1", vm.PairedDevice);
    }

    [Fact]
    public void Stopped_ShowsStopped()
    {
        var vm = new ConnectionViewModel();

        vm.UpdateFrom(ManagerWithActiveDevice(), isRunning: false, port: 8765, connectedDeviceIds: null);

        Assert.Equal("Stopped", vm.StatusText);
        Assert.False(vm.IsDeviceConnected);
    }

    [Fact]
    public void NoPairedDevice_ShowsNone()
    {
        var vm = new ConnectionViewModel();

        vm.UpdateFrom(new PairingManager(), isRunning: true, port: 8765);

        Assert.Equal("None", vm.PairedDevice);
        Assert.Equal("Listening on port 8765", vm.StatusText);
    }

    private static PairingManager ManagerWithActiveDevice()
    {
        var manager = new PairingManager();
        manager.ValidatePairing("phone-1", manager.GeneratePairingCode().Code);
        manager.SetActiveDevice("phone-1");
        return manager;
    }
}
