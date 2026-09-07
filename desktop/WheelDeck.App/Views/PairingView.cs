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
        ViewModel = new PairingViewModel(pairingManager);
        DataContext = ViewModel;
    }

    /// <summary>The view model driving the device list, exposed so the shell
    /// can refresh it when a pairing completes. Null in the designer preview.</summary>
    public PairingViewModel? ViewModel { get; }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);
}
