using WheelDeck.App.ViewModels;
using WheelDeck.Core.Protocol;
using Xunit;

namespace WheelDeck.Tests;

public sealed class WheelMonitorViewModelTests
{
    [Fact]
    public void HiddenByDefault()
    {
        var vm = new WheelMonitorViewModel();

        Assert.False(vm.IsMonitorVisible);
    }

    [Fact]
    public void ToggleMonitorCommand_FlipsVisibility()
    {
        var vm = new WheelMonitorViewModel();

        vm.ToggleMonitorCommand.Execute(null);
        Assert.True(vm.IsMonitorVisible);

        vm.ToggleMonitorCommand.Execute(null);
        Assert.False(vm.IsMonitorVisible);
    }

    [Fact]
    public void UpdateFrom_StoresSteering()
    {
        var vm = new WheelMonitorViewModel();

        vm.UpdateFrom(new StateMessage { Steering = 0.5 });

        Assert.Equal(0.5, vm.Steering);
    }

    [Fact]
    public void UpdateFrom_ClampsSteering()
    {
        var vm = new WheelMonitorViewModel();

        vm.UpdateFrom(new StateMessage { Steering = 5.0 });
        Assert.Equal(1.0, vm.Steering);

        vm.UpdateFrom(new StateMessage { Steering = -5.0 });
        Assert.Equal(-1.0, vm.Steering);
    }

    [Theory]
    [InlineData(-1.0, -135.0)]
    [InlineData(0.0, 0.0)]
    [InlineData(1.0, 135.0)]
    public void NeedleAngle_MapsSteeringToDial(double steering, double expected)
    {
        var vm = new WheelMonitorViewModel();

        vm.UpdateFrom(new StateMessage { Steering = steering });

        Assert.Equal(expected, vm.NeedleAngle);
    }
}
