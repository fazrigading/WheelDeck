using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using WheelDeck.App.ViewModels;
using WheelDeck.Core.Pairing;

namespace WheelDeck.App.Views;

public sealed partial class PairingView : UserControl
{
    public PairingView()
    {
        InitializeComponent();
    }

    public PairingView(PairingManager pairingManager)
    {
        InitializeComponent();
        DataContext = new PairingViewModel(pairingManager);
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);
}
