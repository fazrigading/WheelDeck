using Avalonia.Controls;
using WheelDeck.App.ViewModels;
using WheelDeck.App.Views;
using WheelDeck.Core.Pairing;

namespace WheelDeck.App;

public sealed class MainWindow : Window
{
    public MainWindow()
    {
        Title = "WheelDeck";
        Width = 520;
        Height = 420;

        var pairingManager = new PairingManager();
        var connectionViewModel = new ConnectionViewModel();
        var setupViewModel = new SetupViewModel(new SetupChecker());

        Content = new TabControl
        {
            Items =
            {
                new TabItem { Header = "Connection", Content = new ConnectionView(connectionViewModel) },
                new TabItem { Header = "Pairing", Content = new PairingView(pairingManager) },
                new TabItem { Header = "Setup", Content = new SetupView(setupViewModel) }
            }
        };
    }
}
