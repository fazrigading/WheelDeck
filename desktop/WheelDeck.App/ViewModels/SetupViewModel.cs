using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace WheelDeck.App.ViewModels;

/// <summary>Backs the setup tab: runs the first-run check and shows the result.</summary>
public sealed class SetupViewModel : INotifyPropertyChanged
{
    private readonly SetupChecker _checker;
    private string _message = "Not checked yet.";

    public event PropertyChangedEventHandler? PropertyChanged;

    public string Message
    {
        get => _message;
        private set => SetField(ref _message, value);
    }

    public RelayCommand CheckCommand { get; }

    public SetupViewModel(SetupChecker checker)
    {
        _checker = checker;
        CheckCommand = new RelayCommand(_ => RunCheck());
    }

    private void RunCheck()
    {
        Message = _checker.Check().Message;
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
