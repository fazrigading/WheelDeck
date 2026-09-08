using WheelDeck.Core.Network;
using Xunit;

namespace WheelDeck.Tests;

public sealed class NetworkHelperTests
{
    [Fact]
    public void GetLocalIpAddressReturnsNonEmptyString()
    {
        var ip = NetworkHelper.GetLocalIpAddress();

        Assert.NotNull(ip);
        Assert.NotEmpty(ip);
    }

    [Fact]
    public void GetLocalIpAddressReturnsValidFormat()
    {
        var ip = NetworkHelper.GetLocalIpAddress();

        Assert.True(
            ip == "Unknown" || System.Net.IPAddress.TryParse(ip, out _),
            $"Expected a valid IP address or \"Unknown\", got: {ip}");
    }
}
