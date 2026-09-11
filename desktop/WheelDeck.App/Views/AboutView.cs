using System.Reflection;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Markup.Xaml;

namespace WheelDeck.App.Views;

public sealed partial class AboutView : UserControl
{
    public AboutView()
    {
        InitializeComponent();
        var version = Assembly.GetEntryAssembly()?.GetName().Version?.ToString() ?? "?";
        this.FindControl<TextBlock>("VersionText")!.Text = $"WheelDeck {version}";
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    private void OnRepoClick(object? sender, RoutedEventArgs e) =>
        Browser.Open("https://github.com/fazrigading/WheelDeck", this);
}
