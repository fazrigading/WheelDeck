using System.ComponentModel;
using System.Runtime.CompilerServices;
using WheelDeck.Core.Pairing;

namespace WheelDeck.App.ViewModels;

/// <summary>
/// State shown on the connection management screen: server status, the active paired
/// device, and a firewall reminder for when connections cannot reach the desktop.
/// </summary>
public sealed class ConnectionViewModel : INotifyPropertyChanged
{
    private bool _isRunning;
    private string _statusText = "Stopped";
    private string _activeDevice = "None";
    private int _port;

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

    public string ActiveDevice
    {
        get => _activeDevice;
        set => SetField(ref _activeDevice, value);
    }

    public int Port
    {
        get => _port;
        set => SetField(ref _port, value);
    }

    public string FirewallReminder =>
        "If a phone cannot connect, allow WheelDeck through the firewall and confirm both devices are on the same local network.";

    public void UpdateFrom(PairingManager pairingManager, bool isRunning, int port)
    {
        IsRunning = isRunning;
        Port = port;
        StatusText = isRunning ? $"Listening on port {port}" : "Stopped";

        var active = pairingManager.ListPairedDevices().FirstOrDefault(d => d.IsActive);
        ActiveDevice = active is null ? "None" : active.DisplayName;
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
}
