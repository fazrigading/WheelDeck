using Avalonia.Styling;
using WheelDeck.App;
using Xunit;

namespace WheelDeck.Tests;

public sealed class ThemeSettingsTests
{
    [Fact]
    public void MissingFile_FollowsSystem()
    {
        Assert.Null(ThemeSettings.Load(Path.Combine(Path.GetTempPath(), Path.GetRandomFileName())));
    }

    [Fact]
    public void SaveLoad_RoundTrips()
    {
        var path = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        try
        {
            ThemeSettings.Save(ThemeVariant.Dark, path);
            Assert.Equal(ThemeVariant.Dark, ThemeSettings.Load(path));

            ThemeSettings.Save(ThemeVariant.Light, path);
            Assert.Equal(ThemeVariant.Light, ThemeSettings.Load(path));

            ThemeSettings.Save(null, path);
            Assert.Null(ThemeSettings.Load(path));
            Assert.False(File.Exists(path));
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void UnknownContent_FollowsSystem()
    {
        var path = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        try
        {
            File.WriteAllText(path, "neon");
            Assert.Null(ThemeSettings.Load(path));
        }
        finally
        {
            File.Delete(path);
        }
    }
}
