using WheelDeck.Core.Pairing;
using Xunit;

namespace WheelDeck.Tests;

public sealed class PairingManagerTests
{
    private static readonly DateTimeOffset FixedNow = new(2026, 9, 3, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void PairedDevicesSurviveReload()
    {
        var store = new InMemoryPairingStore();

        var first = new PairingManager(store, () => FixedNow);
        var code = first.GeneratePairingCode().Code;
        var result = first.ValidatePairing("phone-1", code);

        Assert.True(result.Accepted);
        Assert.NotNull(store.Saved);
        Assert.Single(store.Saved);

        var reloaded = new PairingManager(store, () => FixedNow);
        var devices = reloaded.ListPairedDevices();

        var device = Assert.Single(devices);
        Assert.Equal("phone-1", device.Id);
        Assert.Equal(FixedNow, device.LastSeenAt);
    }

    [Fact]
    public void ExpiryUsesPersistedLastSeenAfterReload()
    {
        var store = new InMemoryPairingStore();

        var first = new PairingManager(store, () => FixedNow);
        var code = first.GeneratePairingCode().Code;
        first.ValidatePairing("phone-1", code);

        var later = FixedNow.AddDays(31);
        var reloaded = new PairingManager(store, () => later);

        var device = Assert.Single(reloaded.ListPairedDevices());
        Assert.True(reloaded.IsExpired(device));
    }

    [Fact]
    public void TouchLastSeenPersistsAndPreventsExpiry()
    {
        var store = new InMemoryPairingStore();

        var first = new PairingManager(store, () => FixedNow);
        var code = first.GeneratePairingCode().Code;
        first.ValidatePairing("phone-1", code);

        var later = FixedNow.AddDays(10);
        first.TouchLastSeen("phone-1");

        var reloaded = new PairingManager(store, () => later);
        var device = Assert.Single(reloaded.ListPairedDevices());
        Assert.False(reloaded.IsExpired(device));
    }

    [Fact]
    public async Task ConcurrentCallsProduceConsistentFinalState()
    {
        var store = new InMemoryPairingStore();
        var manager = new PairingManager(store, () => FixedNow);

        var deviceIds = new[] { "phone-a", "phone-b", "phone-c" };
        foreach (var id in deviceIds)
        {
            var code = manager.GeneratePairingCode();
            Assert.True(manager.ValidatePairing(id, code.Code).Accepted);
        }

        manager.SetActiveDevice("phone-a");

        var tasks = new List<Task>();
        for (var i = 0; i < 100; i++)
        {
            var id = deviceIds[i % deviceIds.Length];
            tasks.Add(Task.Run(() => manager.TouchLastSeen(id)));
            tasks.Add(Task.Run(() => manager.SetActiveDevice(id)));
        }

        await Task.WhenAll(tasks);

        var devices = manager.ListPairedDevices();
        Assert.Single(devices, d => d.IsActive);
        Assert.Equal(3, devices.Count);
    }
}
