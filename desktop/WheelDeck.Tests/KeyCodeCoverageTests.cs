using System.Reflection;
using WheelDeck.Backends.Linux;
using WheelDeck.Backends.Windows;
using WheelDeck.Core.Output;
using Xunit;

namespace WheelDeck.Tests;

/// <summary>
/// Every KeyCode must have a row in both backend key tables. A missing row makes
/// SendKey silently drop the key, so total coverage is enforced here. Ticket #33.
/// </summary>
public sealed class KeyCodeCoverageTests
{
    private static readonly KeyCode[] ExpectedKeys =
        Enum.GetValues<KeyCode>().Where(k => k != KeyCode.None).ToArray();

    [Fact]
    public void EveryKeyCode_HasWindowsVirtualKeyCode()
    {
        var rows = TableRows(typeof(SendInputKeySimulator), "VirtualKeyCodes");
        Assert.Empty(ExpectedKeys.Except(rows));
    }

    [Fact]
    public void EveryKeyCode_HasLinuxEvdevCode()
    {
        var rows = TableRows(typeof(UinputBackend), "KeyCodes");
        Assert.Empty(ExpectedKeys.Except(rows));
    }

    private static HashSet<KeyCode> TableRows(Type backendType, string fieldName)
    {
        var field = backendType.GetField(fieldName, BindingFlags.NonPublic | BindingFlags.Static);
        Assert.False(field is null, $"Expected private static table '{fieldName}' on {backendType.Name}.");
        var table = (System.Collections.IDictionary)field!.GetValue(null)!;
        var rows = new HashSet<KeyCode>();
        foreach (KeyCode key in table.Keys)
        {
            rows.Add(key);
        }

        return rows;
    }
}
