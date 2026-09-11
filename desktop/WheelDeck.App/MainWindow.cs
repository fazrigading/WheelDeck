using Avalonia.Controls;
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

        Content = new TabControl
        {
            Items =
            {
                new TabItem { Header = "Connection", Content = new ConnectionView(connectionViewModel) },
                new TabItem { Header = "Pairing", Content = pairingView },
                new TabItem { Header = "Setup", Content = new SetupView(setupViewModel) }
            }
        };

        Closing += (_, _) =>
        {
            _root.StopAsync().GetAwaiter().GetResult();
        };
    }
}
