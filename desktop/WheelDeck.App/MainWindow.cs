using Avalonia.Controls;
using WheelDeck.App.Views;

namespace WheelDeck.App;

public sealed class MainWindow : Window
{
    public MainWindow()
    {
        Title = "WheelDeck";
        Width = 480;
        Height = 360;
        Content = new ConnectionView();
    }
}
