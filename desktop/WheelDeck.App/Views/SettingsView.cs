using Avalonia;
using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using WheelDeck.App.ViewModels;
using WheelDeck.Core.Network;

namespace WheelDeck.App.Views;

public sealed partial class SettingsView : UserControl
{
    public SettingsView()
        : this(new SettingsViewModel(
            () => Application.Current?.RequestedThemeVariant,
            MainWindow.ApplyTheme,
            $"Listening on port {WebSocketListener.DefaultPort}"))
    {
    }

    public SettingsView(SettingsViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);
}
