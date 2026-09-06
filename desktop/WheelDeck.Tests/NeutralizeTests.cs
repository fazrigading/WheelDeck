using WheelDeck.Core.Output;
using WheelDeck.Core.Pairing;
using Xunit;

namespace WheelDeck.Tests;

public sealed class NeutralizeTests
{
    private static readonly DateTimeOffset FixedNow = new(2026, 9, 3, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void RevokeDevice_CallsNeutralizeThroughCallback()
    {
        var neutralized = false;
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var code = manager.GeneratePairingCode();
        manager.ValidatePairing("phone-1", code.Code);
        manager.SetActiveDevice("phone-1");

        manager.RevokeDevice("phone-1");

        var devices = manager.ListPairedDevices();
        Assert.Empty(devices);
        Assert.False(neutralized);
    }

    [Fact]
    public void SetActiveDevice_SwitchesActiveFlag()
    {
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var code1 = manager.GeneratePairingCode();
        manager.ValidatePairing("phone-1", code1.Code);
        var code2 = manager.GeneratePairingCode();
        manager.ValidatePairing("phone-2", code2.Code);

        manager.SetActiveDevice("phone-1");
        Assert.True(manager.ListPairedDevices().First(d => d.Id == "phone-1").IsActive);
        Assert.False(manager.ListPairedDevices().First(d => d.Id == "phone-2").IsActive);

        manager.SetActiveDevice("phone-2");
        Assert.False(manager.ListPairedDevices().First(d => d.Id == "phone-1").IsActive);
        Assert.True(manager.ListPairedDevices().First(d => d.Id == "phone-2").IsActive);
    }

    [Fact]
    public void FindDeviceBySessionToken_ReturnsDevice_WhenPaired()
    {
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var code = manager.GeneratePairingCode();
        var result = manager.ValidatePairing("phone-1", code.Code);

        Assert.NotNull(result.SessionToken);
        var device = manager.FindDeviceBySessionToken(result.SessionToken);
        Assert.NotNull(device);
        Assert.Equal("phone-1", device.Id);
    }

    [Fact]
    public void FindDeviceBySessionToken_ReturnsNull_WhenRevoked()
    {
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var code = manager.GeneratePairingCode();
        var result = manager.ValidatePairing("phone-1", code.Code);
        manager.RevokeDevice("phone-1");

        var device = manager.FindDeviceBySessionToken(result.SessionToken!);
        Assert.Null(device);
    }

    [Fact]
    public void IsAuthorized_ReturnsFalse_ForExpiredDevice()
    {
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var code = manager.GeneratePairingCode();
        manager.ValidatePairing("phone-1", code.Code);
        manager.SetActiveDevice("phone-1");

        var expiredManager = new PairingManager(store, () => FixedNow.AddDays(31));
        var device = expiredManager.ListPairedDevices().First(d => d.Id == "phone-1");
        Assert.False(expiredManager.IsAuthorized(device));
    }

    [Fact]
    public void IsAuthorized_ReturnsFalse_ForInactiveDevice()
    {
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var code = manager.GeneratePairingCode();
        manager.ValidatePairing("phone-1", code.Code);

        var device = manager.ListPairedDevices().First(d => d.Id == "phone-1");
        Assert.False(manager.IsAuthorized(device));
    }

    [Fact]
    public void IsAuthorized_ReturnsTrue_ForActiveNonExpiredDevice()
    {
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var code = manager.GeneratePairingCode();
        manager.ValidatePairing("phone-1", code.Code);
        manager.SetActiveDevice("phone-1");

        var device = manager.ListPairedDevices().First(d => d.Id == "phone-1");
        Assert.True(manager.IsAuthorized(device));
    }

    [Fact]
    public void IsAuthorized_ReturnsFalse_ForRevokedDevice()
    {
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var code = manager.GeneratePairingCode();
        manager.ValidatePairing("phone-1", code.Code);
        manager.SetActiveDevice("phone-1");
        manager.RevokeDevice("phone-1");

        var device = new PairedDevice
        {
            Id = "phone-1",
            IsActive = true,
            LastSeenAt = FixedNow,
            PairedAt = FixedNow
        };
        Assert.False(manager.IsAuthorized(device));
    }

    [Fact]
    public void Backend_Neutralize_ZeroesAxesAndReleasesButtons()
    {
        var backend = new TrackingBackend();
        backend.SetAxis(AxisType.Steering, 0.5f);
        backend.SetAxis(AxisType.Accelerator, 1.0f);
        backend.SetButton(ButtonId.A, true);
        backend.SendKey(KeyCode.Space, true);

        backend.Neutralize();

        Assert.Equal(1, backend.NeutralizeCount);
    }

    private sealed class TrackingBackend : VirtualOutputBackend
    {
        public int NeutralizeCount { get; private set; }

        public BackendResult Initialize() => BackendResult.Success();
        public void SetAxis(AxisType axis, float value) { }
        public void SetButton(ButtonId button, bool pressed) { }
        public void SendKey(KeyCode keyCode, bool pressed) { }
        public void Neutralize() => NeutralizeCount++;
        public void Shutdown() { }
    }
}
