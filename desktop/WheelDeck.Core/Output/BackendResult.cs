namespace WheelDeck.Core.Output;

/// <summary>
/// Outcome of a backend operation such as initialize(). Carries an optional error
/// message so the app can surface missing drivers or permissions to the user.
/// </summary>
public readonly record struct BackendResult(bool IsSuccess, string? Error = null)
{
    public static BackendResult Success() => new(true);

    public static BackendResult Failure(string error) => new(false, error);
}
