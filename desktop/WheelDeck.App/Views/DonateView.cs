using System.Reflection;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Markup.Xaml;

namespace WheelDeck.App.Views;

public sealed partial class DonateView : UserControl
{
    public DonateView()
    {
        InitializeComponent();
        var version = Assembly.GetEntryAssembly()?.GetName().Version?.ToString() ?? "?";
        this.FindControl<TextBlock>("VersionText")!.Text = $"WheelDeck {version}";
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    private void OnBuyMeACoffeeClick(object? sender, RoutedEventArgs e) =>
        Browser.Open("https://buymeacoffee.com/fazrigading", this);

    private void OnPayPalClick(object? sender, RoutedEventArgs e) =>
        Browser.Open("https://paypal.me/fazrigading", this);

    private void OnKoFiClick(object? sender, RoutedEventArgs e) =>
        Browser.Open("https://ko-fi.com/fazrigading", this);

    private void OnRepoClick(object? sender, RoutedEventArgs e) =>
        Browser.Open("https://github.com/fazrigading/WheelDeck", this);
}
