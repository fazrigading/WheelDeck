using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using WheelDeck.App.ViewModels;

namespace WheelDeck.App.Views;

public sealed partial class ConnectionView : UserControl
{
    public ConnectionView()
    {
        InitializeComponent();
        DataContext = new ConnectionViewModel();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);
}
