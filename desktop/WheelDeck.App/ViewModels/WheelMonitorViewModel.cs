using System.ComponentModel;
using System.Windows.Input;
using WheelDeck.Core.Protocol;

namespace WheelDeck.App.ViewModels;

/// <summary>Display-only mirror of live phone steering for manual testing.
/// Updated from authorized state messages via <see cref="UpdateFrom"/>; never
/// drives output and never touches the input mapper.</summary>
public sealed class WheelMonitorViewModel : INotifyPropertyChanged
{
    private double _steering;
    private bool _isMonitorVisible;

    public event PropertyChangedEventHandler? PropertyChanged;

    /// <summary>Latest normalized steering (-1.0..1.0).</summary>
    public double Steering => _steering;

    /// <summary>Needle rotation for a <c>RotateTransform</c> on an up-pointing
    /// needle over a 270-degree dial (-135 at full left, 0 centered,
    /// +135 at full right).</summary>
    public double NeedleAngle => _steering * 135;

    /// <summary>Signed readout of the current steering value.</summary>
    public string SteeringText => _steering.ToString("+0.00;-0.00;0.00");

    /// <summary>Whether the monitor widget is shown. Hidden by default.</summary>
    public bool IsMonitorVisible
    {
        get => _isMonitorVisible;
        private set
        {
            _isMonitorVisible = value;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(IsMonitorVisible)));
        }
    }

    public ICommand ToggleMonitorCommand { get; }

    public WheelMonitorViewModel()
    {
        ToggleMonitorCommand = new RelayCommand(_ => IsMonitorVisible = !IsMonitorVisible);
    }

    /// <summary>Records the latest steering value. Call on the UI thread.</summary>
    public void UpdateFrom(StateMessage state)
    {
        _steering = Math.Clamp(state.Steering, -1.0, 1.0);
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Steering)));
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(NeedleAngle)));
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(SteeringText)));
    }
}
