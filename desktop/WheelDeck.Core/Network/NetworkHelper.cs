using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace WheelDeck.Core.Network;

/// <summary>
/// Helpers that resolve local network information without depending on a specific
/// listener or socket instance.
/// </summary>
public static class NetworkHelper
{
    /// <summary>
    /// Returns the first usable non-loopback IPv4 address on this machine.
    /// Prefers addresses in common LAN ranges (192.168.x.x, 10.x.x.x).
    /// Returns <c>"Unknown"</c> when no suitable address is found.
    /// </summary>
    public static string GetLocalIpAddress()
    {
        try
        {
            var candidates = NetworkInterface.GetAllNetworkInterfaces()
                .Where(ni => ni.OperationalStatus == OperationalStatus.Up
                             && ni.NetworkInterfaceType != NetworkInterfaceType.Loopback)
                .SelectMany(ni => ni.GetIPProperties().UnicastAddresses)
                .Where(ua => ua.Address.AddressFamily == AddressFamily.InterNetwork
                             && !IPAddress.IsLoopback(ua.Address))
                .Select(ua => ua.Address)
                .OrderByDescending(IsLanRange)
                .ThenByDescending(a => a.ToString().StartsWith("192.168."))
                .ToList();

            return candidates.Count > 0
                ? candidates[0].ToString()
                : "Unknown";
        }
        catch
        {
            return "Unknown";
        }
    }

    private static bool IsLanRange(IPAddress address)
    {
        var octets = address.GetAddressBytes();
        return octets[0] == 192 && octets[1] == 168
               || octets[0] == 10;
    }
}
