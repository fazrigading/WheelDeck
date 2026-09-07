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
        Width = 520;
        Height = 420;

        _root = new CompositionRoot();
        _root.Start();

        var pairingManager = _root.PairingManager;
        var connectionViewModel = new ConnectionViewModel();
        var setupViewModel = new SetupViewModel(new SetupChecker());

        connectionViewModel.UpdateFrom(pairingManager, isRunning: true, WebSocketListener.DefaultPort);

        var pairingView = new PairingView(pairingManager);

        // A phone pairing in the background must show up immediately: refresh
        // the active-device label and the device list on the UI thread.
        _root.PairingService.PairingCompleted += (_, _, _) =>
        {
            Avalonia.Threading.Dispatcher.UIThread.Post(() =>
            {
                connectionViewModel.UpdateFrom(pairingManager, isRunning: true, WebSocketListener.DefaultPort);
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
