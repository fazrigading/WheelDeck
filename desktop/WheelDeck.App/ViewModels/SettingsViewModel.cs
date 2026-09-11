using System.ComponentModel;
using System.Windows.Input;
using Avalonia.Styling;

namespace WheelDeck.App.ViewModels;

/// <summary>App settings: theme choice and connection info. Theme reads/writes
/// through injected delegates so tests never touch the running app.</summary>
public sealed class SettingsViewModel : INotifyPropertyChanged
{
    private readonly Func<ThemeVariant?> _getCurrent;
    private readonly Action<ThemeVariant?> _apply;

    public event PropertyChangedEventHandler? PropertyChanged;

    public string PortInfo { get; }

    public string ThemeLabel => ReferenceEquals(_getCurrent(), ThemeVariant.Dark) ? "Dark"
        : ReferenceEquals(_getCurrent(), ThemeVariant.Light) ? "Light"
        : "System";

    public ICommand UseSystemThemeCommand { get; }
    public ICommand UseLightThemeCommand { get; }
    public ICommand UseDarkThemeCommand { get; }

    public SettingsViewModel(Func<ThemeVariant?> getCurrent, Action<ThemeVariant?> apply, string portInfo)
    {
        _getCurrent = getCurrent;
        _apply = apply;
        PortInfo = portInfo;
        UseSystemThemeCommand = new RelayCommand(_ => SetTheme(null));
        UseLightThemeCommand = new RelayCommand(_ => SetTheme(ThemeVariant.Light));
        UseDarkThemeCommand = new RelayCommand(_ => SetTheme(ThemeVariant.Dark));
    }

    private void SetTheme(ThemeVariant? variant)
    {
        _apply(variant);
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(ThemeLabel)));
    }
}
