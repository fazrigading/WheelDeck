using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using WheelDeck.App.ViewModels;

namespace WheelDeck.App.Views;

public sealed partial class SetupView : UserControl
{
    public SetupView()
    {
        InitializeComponent();
        DataContext = new SetupViewModel(new SetupChecker());
    }

    public SetupView(SetupViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);
}
