using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using WheelDeck.Core.Pairing;

namespace WheelDeck.App.ViewModels;

/// <summary>One row in the paired-device list.</summary>
public sealed class PairedDeviceRow : INotifyPropertyChanged
{
    private string _displayName = string.Empty;
    private bool _isActive;

    public event PropertyChangedEventHandler? PropertyChanged;

    public required string Id { get; init; }

    public string DisplayName
    {
        get => _displayName;
        set => SetField(ref _displayName, value);
    }

    public bool IsActive
    {
        get => _isActive;
        set => SetField(ref _isActive, value);
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

/// <summary>
/// Drives the pairing screen: shows a fresh pairing code and a list of paired devices
/// with set-active and revoke actions.
/// </summary>
public sealed class PairingViewModel : INotifyPropertyChanged
{
    private readonly PairingManager _pairingManager;
    private string _pairingCode = string.Empty;

    public event PropertyChangedEventHandler? PropertyChanged;

    public ObservableCollection<PairedDeviceRow> Devices { get; } = new();

    public string PairingCode
    {
        get => _pairingCode;
        private set => SetField(ref _pairingCode, value);
    }

    public RelayCommand GenerateCodeCommand { get; }
    public RelayCommand SetActiveCommand { get; }
    public RelayCommand RevokeCommand { get; }

    public PairingViewModel(PairingManager pairingManager)
    {
        _pairingManager = pairingManager;

        GenerateCodeCommand = new RelayCommand(_ => GenerateCode());
        SetActiveCommand = new RelayCommand(p => SetActive((string?)p));
        RevokeCommand = new RelayCommand(p => Revoke((string?)p));

        RefreshDevices();
    }

    private void GenerateCode()
    {
        PairingCode = _pairingManager.GeneratePairingCode().Code;
    }

    private void SetActive(string? deviceId)
    {
        if (deviceId is null)
        {
            return;
        }

        _pairingManager.SetActiveDevice(deviceId);
        RefreshDevices();
    }

    private void Revoke(string? deviceId)
    {
        if (deviceId is null)
        {
            return;
        }

        _pairingManager.RevokeDevice(deviceId);
        RefreshDevices();
    }

    private void RefreshDevices()
    {
        Devices.Clear();
        foreach (var device in _pairingManager.ListPairedDevices())
        {
            Devices.Add(new PairedDeviceRow
            {
                Id = device.Id,
                DisplayName = device.DisplayName,
                IsActive = device.IsActive
            });
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
}
