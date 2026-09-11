using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Styling;
using WheelDeck.App.ViewModels;
using WheelDeck.App.Views;
using WheelDeck.Core.Network;

namespace WheelDeck.App;

public sealed class MainWindow : Window
{
    private readonly CompositionRoot _root;

    public MainWindow()
    {
        Title = "WheelDeck";
        Width = 880;
        Height = 600;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;

        _root = new CompositionRoot();
        _root.Start();

        var pairingManager = _root.PairingManager;
        var connectionViewModel = new ConnectionViewModel();
        var setupViewModel = new SetupViewModel(new SetupChecker());

        void RefreshConnection() => connectionViewModel.UpdateFrom(
            pairingManager, isRunning: true, WebSocketListener.DefaultPort, _root.Gate.ConnectedDeviceIds);
        RefreshConnection();

        var pairingView = new PairingView(pairingManager);

        // A phone pairing in the background must show up immediately: refresh
        // the paired-device label and the device list on the UI thread.
        // Same for connect/disconnect: the status card follows live sessions.
        _root.Gate.ConnectionsChanged += () =>
            Avalonia.Threading.Dispatcher.UIThread.Post(RefreshConnection);
        _root.PairingService.PairingCompleted += (_, _, _) =>
        {
            Avalonia.Threading.Dispatcher.UIThread.Post(() =>
            {
                RefreshConnection();
                pairingView.ViewModel?.RefreshDevices();
            });
        };

        var settingsViewModel = new SettingsViewModel(
            getCurrent: () => Application.Current?.RequestedThemeVariant,
            apply: ApplyTheme,
            portInfo: $"Listening on port {WebSocketListener.DefaultPort}");

        var pages = new Dictionary<string, UserControl>
        {
            ["Connection"] = new ConnectionView(connectionViewModel),
            ["Pairing"] = pairingView,
            ["Setup"] = new SetupView(setupViewModel),
            ["Settings"] = new SettingsView(settingsViewModel),
            ["About"] = new AboutView(),
            ["Donate"] = new DonateView(),
        };

        var content = new ContentControl { Content = pages["Connection"] };

        var nav = new StackPanel { Spacing = 4, Margin = new Thickness(12) };
        Button? selected = null;
        foreach (var (name, page) in pages)
        {
            var button = new Button
            {
                Content = name,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Left,
            };
            button.Classes.Add("nav");
            button.Click += (_, _) =>
            {
                content.Content = page;
                if (selected is not null)
                {
                    selected.Classes.Remove("nav-selected");
                }

                button.Classes.Add("nav-selected");
                selected = button;
            };
            nav.Children.Add(button);
            if (name == "Connection")
            {
                button.Classes.Add("nav-selected");
                selected = button;
            }
        }

        var themeButton = new Button { Content = ThemeButtonLabel() };
        themeButton.Click += (_, _) =>
        {
            var next = Application.Current?.RequestedThemeVariant == ThemeVariant.Dark
                ? ThemeVariant.Light
                : ThemeVariant.Dark;
            ApplyTheme(next);
            themeButton.Content = ThemeButtonLabel();
        };

        var title = new TextBlock { Text = "WheelDeck" };
        title.Classes.Add("app-title");
        Grid.SetColumn(title, 1);
        Grid.SetColumn(themeButton, 2);
        themeButton.HorizontalAlignment = HorizontalAlignment.Right;
        var headerGrid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto,*") };
        headerGrid.Children.Add(title);
        headerGrid.Children.Add(themeButton);
        var header = new Border { Child = headerGrid };
        header.Classes.Add("app-header");

        var navPane = new Border
        {
            Width = 170,
            Child = nav,
        };
        navPane.Classes.Add("nav-pane");
        var body = new DockPanel { LastChildFill = true };
        DockPanel.SetDock(navPane, Dock.Left);
        body.Children.Add(navPane);
        body.Children.Add(new Border { Margin = new Thickness(4), Child = content });

        var root = new DockPanel { LastChildFill = true };
        DockPanel.SetDock(header, Dock.Top);
        root.Children.Add(header);
        root.Children.Add(body);

        Content = root;

        Closing += (_, _) =>
        {
            _root.StopAsync().GetAwaiter().GetResult();
        };
    }

    /// <summary>Applies a theme choice and persists it (null follows the system).</summary>
    public static void ApplyTheme(ThemeVariant? variant)
    {
        if (Application.Current is not null)
        {
            Application.Current.RequestedThemeVariant = variant ?? ThemeVariant.Default;
        }

        ThemeSettings.Save(variant);
        Brand.Apply(variant);
    }

    private static string ThemeButtonLabel() =>
        Application.Current?.RequestedThemeVariant == ThemeVariant.Dark ? "Light mode" : "Dark mode";
}
