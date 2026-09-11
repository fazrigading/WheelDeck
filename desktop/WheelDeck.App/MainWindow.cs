using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
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

        var pages = new Dictionary<string, UserControl>
        {
            ["Connection"] = new ConnectionView(connectionViewModel),
            ["Pairing"] = pairingView,
            ["Setup"] = new SetupView(setupViewModel),
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

        var title = new TextBlock
        {
            Text = "WheelDeck",
            FontSize = 18,
            FontWeight = FontWeight.SemiBold,
            VerticalAlignment = VerticalAlignment.Center,
        };
        var header = new DockPanel { Margin = new Thickness(12, 12, 12, 0) };
        DockPanel.SetDock(title, Dock.Left);
        DockPanel.SetDock(themeButton, Dock.Right);
        header.Children.Add(title);
        header.Children.Add(themeButton);

        var navPane = new Border
        {
            Width = 170,
            Margin = new Thickness(0, 12, 0, 12),
            Child = nav,
        };
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
    }

    private static string ThemeButtonLabel() =>
        Application.Current?.RequestedThemeVariant == ThemeVariant.Dark ? "Light mode" : "Dark mode";
}
