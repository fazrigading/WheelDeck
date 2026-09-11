using System.ComponentModel;
using System.Runtime.CompilerServices;
using WheelDeck.Core.Network;
using WheelDeck.Core.Pairing;

namespace WheelDeck.App.ViewModels;

/// <summary>
/// State shown on the connection management screen: server status, the paired
/// device, and a firewall reminder for when connections cannot reach the desktop.
/// </summary>
public sealed class ConnectionViewModel : INotifyPropertyChanged
{
    private bool _isRunning;
    private bool _isDeviceConnected;
    private string _statusText = "Stopped";
    private string _statusColor = "#8A8A8A";
    private string _pairedDevice = "None";
    private int _port;
    private string _localIpAddress = NetworkHelper.GetLocalIpAddress();

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool IsRunning
    {
        get => _isRunning;
        set => SetField(ref _isRunning, value);
    }

    public string StatusText
    {
        get => _statusText;
        set => SetField(ref _statusText, value);
    }

    public bool IsDeviceConnected
    {
        get => _isDeviceConnected;
        set => SetField(ref _isDeviceConnected, value);
    }

    /// <summary>Hex fill for the status dot: muted teal when a device is connected, gray otherwise.</summary>
    public string StatusColor
    {
        get => _statusColor;
        set => SetField(ref _statusColor, value);
    }

    public string PairedDevice
    {
        get => _pairedDevice;
        set => SetField(ref _pairedDevice, value);
    }

    public int Port
    {
        get => _port;
        set
        {
            SetField(ref _port, value);
            OnPropertyChanged(nameof(ConnectionInfo));
        }
    }

    public string LocalIpAddress
    {
        get => _localIpAddress;
        set
        {
            SetField(ref _localIpAddress, value);
            OnPropertyChanged(nameof(ConnectionInfo));
        }
    }

    public string ConnectionInfo => $"{LocalIpAddress}:{Port}";

    public string FirewallReminder =>
        "If a phone cannot connect, allow WheelDeck through the firewall and confirm both devices are on the same local network.";

    public void UpdateFrom(
        PairingManager pairingManager,
        bool isRunning,
        int port,
        IReadOnlyCollection<string>? connectedDeviceIds = null)
    {
        IsRunning = isRunning;
        Port = port;
        LocalIpAddress = NetworkHelper.GetLocalIpAddress();

        var paired = pairingManager.ListPairedDevices();
        var active = paired.FirstOrDefault(d => d.IsActive);
        PairedDevice = active is null ? "None" : active.DisplayName;

        var connectedId = connectedDeviceIds?.FirstOrDefault();
        if (!isRunning)
        {
            IsDeviceConnected = false;
            StatusText = "Stopped";
            StatusColor = "#8A8A8A";
        }
        else if (connectedId is not null)
        {
            IsDeviceConnected = true;
            var name = paired.FirstOrDefault(d => d.Id == connectedId)?.DisplayName ?? connectedId;
            StatusText = $"Connected to {name}";
            StatusColor = "#415A77";
        }
        else
        {
            IsDeviceConnected = false;
            StatusText = $"Listening on port {port}";
            StatusColor = "#8A8A8A";
        }
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
