using System.Text.Json;
using WheelDeck.Core.Protocol;
using Xunit;

namespace WheelDeck.Tests;

public sealed class ProtocolTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
    };

    [Fact]
    public void ButtonMessageSerializesWithSnakeCaseFields()
    {
        var msg = new ButtonMessage
        {
            Control = ControlId.TurnSignalLeft,
            Action = ActionType.Toggle
        };

        var json = JsonSerializer.Serialize(msg, JsonOptions);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("button", root.GetProperty("type").GetString());
        Assert.Equal("turn_signal_left", root.GetProperty("control").GetString());
        Assert.Equal("toggle", root.GetProperty("action").GetString());
    }

    [Fact]
    public void ButtonMessageDeserializesFromSnakeCase()
    {
        var json = """{"type":"button","control":"high_beam_toggle","action":"press"}""";
        var msg = JsonSerializer.Deserialize<ButtonMessage>(json, JsonOptions);

        Assert.NotNull(msg);
        Assert.Equal(ControlId.HighBeamToggle, msg.Control);
        Assert.Equal(ActionType.Press, msg.Action);
    }

    [Fact]
    public void StateMessageSerializesWithAllFields()
    {
        var msg = new StateMessage
        {
            Seq = 42,
            Steering = -0.75,
            Accelerator = 1.0,
            Brake = 0.0,
            Clutch = 0.5
        };

        var json = JsonSerializer.Serialize(msg, JsonOptions);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("state", root.GetProperty("type").GetString());
        Assert.Equal(42, root.GetProperty("seq").GetInt64());
        Assert.Equal(-0.75, root.GetProperty("steering").GetDouble());
        Assert.Equal(1.0, root.GetProperty("accelerator").GetDouble());
        Assert.Equal(0.0, root.GetProperty("brake").GetDouble());
        Assert.Equal(0.5, root.GetProperty("clutch").GetDouble());
    }

    [Fact]
    public void StateMessageDeserializesFromJson()
    {
        var json = """{"type":"state","seq":7,"steering":0.25,"accelerator":0.8,"brake":0.1,"clutch":0.0}""";
        var msg = JsonSerializer.Deserialize<StateMessage>(json, JsonOptions);

        Assert.NotNull(msg);
        Assert.Equal(7, msg.Seq);
        Assert.Equal(0.25, msg.Steering);
        Assert.Equal(0.8, msg.Accelerator);
        Assert.Equal(0.1, msg.Brake);
        Assert.Equal(0.0, msg.Clutch);
    }

    [Fact]
    public void PairRequestSerializesWithSnakeCaseFields()
    {
        var msg = new PairRequest
        {
            DeviceId = "phone-1",
            Code = "123456"
        };

        var json = JsonSerializer.Serialize(msg, JsonOptions);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("pair_request", root.GetProperty("type").GetString());
        Assert.Equal("phone-1", root.GetProperty("device_id").GetString());
        Assert.Equal("123456", root.GetProperty("code").GetString());
    }

    [Fact]
    public void PairResponseSerializesAcceptedWithSessionToken()
    {
        var msg = new PairResponse
        {
            DeviceId = "phone-1",
            Accepted = true,
            SessionToken = "tok-abc"
        };

        var json = JsonSerializer.Serialize(msg, JsonOptions);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("pair_response", root.GetProperty("type").GetString());
        Assert.True(root.GetProperty("accepted").GetBoolean());
        Assert.Equal("tok-abc", root.GetProperty("session_token").GetString());
    }

    [Fact]
    public void PairResponseSerializesRejectedWithoutToken()
    {
        var msg = new PairResponse
        {
            DeviceId = "phone-1",
            Accepted = false
        };

        var json = JsonSerializer.Serialize(msg, JsonOptions);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.False(root.GetProperty("accepted").GetBoolean());
        Assert.False(root.TryGetProperty("session_token", out _));
    }

    [Fact]
    public void HeartbeatSerializesWithOptionalToken()
    {
        var msg = new Heartbeat { SessionToken = "tok-xyz" };
        var json = JsonSerializer.Serialize(msg, JsonOptions);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("heartbeat", root.GetProperty("type").GetString());
        Assert.Equal("tok-xyz", root.GetProperty("session_token").GetString());
    }

    [Fact]
    public void HeartbeatSerializesWithoutToken()
    {
        var msg = new Heartbeat();
        var json = JsonSerializer.Serialize(msg, JsonOptions);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("heartbeat", root.GetProperty("type").GetString());
        Assert.False(root.TryGetProperty("session_token", out _));
    }

    [Fact]
    public void DeviceSwitchSerializesWithDeviceId()
    {
        var msg = new DeviceSwitch { DeviceId = "phone-2" };
        var json = JsonSerializer.Serialize(msg, JsonOptions);
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("device_switch", root.GetProperty("type").GetString());
        Assert.Equal("phone-2", root.GetProperty("device_id").GetString());
    }

    [Fact]
    public void SnakeCaseEnumConverter_RoundTripsAllActionTypes()
    {
        foreach (var action in Enum.GetValues<ActionType>())
        {
            var msg = new ButtonMessage { Control = ControlId.ParkingBrake, Action = action };
            var json = JsonSerializer.Serialize(msg, JsonOptions);
            var doc = JsonDocument.Parse(json);
            var wire = doc.RootElement.GetProperty("action").GetString();

            var deserialized = JsonSerializer.Deserialize<ButtonMessage>(json, JsonOptions);
            Assert.Equal(action, deserialized!.Action);
        }
    }

    [Fact]
    public void SnakeCaseEnumConverter_RoundTripsAllControlIds()
    {
        foreach (var control in Enum.GetValues<ControlId>())
        {
            var msg = new ButtonMessage { Control = control, Action = ActionType.Press };

            var json = JsonSerializer.Serialize(msg, JsonOptions);
            var deserialized = JsonSerializer.Deserialize<ButtonMessage>(json, JsonOptions);
            Assert.Equal(control, deserialized!.Control);
        }
    }
}
