using System.Security.Cryptography;

namespace WheelDeck.Core.Pairing;

/// <summary>
/// Manages pairing and session state for phones connecting to the desktop. Enforces the
/// 30-day inactivity expiry and the rule that only the active, non-expired, non-revoked
/// device may reach the input mapper.
/// </summary>
public sealed class PairingManager
{
    private const int PairingCodeLength = 6;
    private static readonly TimeSpan PairingCodeLifetime = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan InactivityExpiry = TimeSpan.FromDays(30);

    private readonly Func<DateTimeOffset> _now;
    private readonly Dictionary<string, PairedDevice> _devices = new();
    private readonly Dictionary<string, PairingCode> _pendingCodes = new();
    private readonly Dictionary<string, string> _sessionTokens = new();

    public PairingManager(Func<DateTimeOffset>? now = null)
    {
        _now = now ?? (() => DateTimeOffset.UtcNow);
    }

    /// <summary>Issues a fresh one-time pairing code the user enters or scans on the phone.</summary>
    public PairingCode GeneratePairingCode()
    {
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        var pairingCode = new PairingCode(code, _now().Add(PairingCodeLifetime));

        _pendingCodes[code] = pairingCode;
        PruneExpiredCodes();

        return pairingCode;
    }

    /// <summary>Validates a pairing request and, on success, pairs the device and issues a session token.</summary>
    public PairingResult ValidatePairing(string deviceId, string code)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(deviceId);
        ArgumentException.ThrowIfNullOrWhiteSpace(code);

        if (!_pendingCodes.TryGetValue(code, out var pending))
        {
            return new PairingResult(false);
        }

        _pendingCodes.Remove(code);

        if (pending.ExpiresAt <= _now())
        {
            return new PairingResult(false);
        }

        var token = NewSessionToken();
        var now = _now();

        var device = new PairedDevice
        {
            Id = deviceId,
            DisplayName = deviceId,
            PairedAt = now,
            LastSeenAt = now,
            IsActive = false
        };

        _devices[deviceId] = device;
        _sessionTokens[token] = deviceId;

        return new PairingResult(true, token);
    }

    /// <summary>Returns all paired devices, including revoked ones until they are pruned.</summary>
    public IReadOnlyList<PairedDevice> ListPairedDevices() => _devices.Values.ToList();

    /// <summary>Sets the given device as the sole active device. All others become inactive.</summary>
    public void SetActiveDevice(string deviceId)
    {
        if (!_devices.TryGetValue(deviceId, out var device))
        {
            throw new KeyNotFoundException($"No paired device with id '{deviceId}'.");
        }

        foreach (var other in _devices.Values)
        {
            other.IsActive = false;
        }

        device.IsActive = true;
        device.LastSeenAt = _now();
    }

    /// <summary>Revokes a device, removing it from the trusted set.</summary>
    public void RevokeDevice(string deviceId)
    {
        if (_devices.Remove(deviceId))
        {
            foreach (var token in _sessionTokens.Where(kvp => kvp.Value == deviceId).Select(kvp => kvp.Key).ToList())
            {
                _sessionTokens.Remove(token);
            }
        }
    }

    /// <summary>True when the device has not been seen for more than 30 days.</summary>
    public bool IsExpired(PairedDevice device) =>
        _now() - device.LastSeenAt > InactivityExpiry;

    /// <summary>Marks a device as recently seen, called on every heartbeat.</summary>
    public void TouchLastSeen(string deviceId)
    {
        if (_devices.TryGetValue(deviceId, out var device))
        {
            device.LastSeenAt = _now();
        }
    }

    /// <summary>Returns the device a session token belongs to, or null when unknown.</summary>
    public PairedDevice? FindDeviceBySessionToken(string sessionToken) =>
        _sessionTokens.TryGetValue(sessionToken, out var deviceId) && _devices.TryGetValue(deviceId, out var device)
            ? device
            : null;

    private void PruneExpiredCodes()
    {
        var now = _now();
        foreach (var code in _pendingCodes.Where(kvp => kvp.Value.ExpiresAt <= now).Select(kvp => kvp.Key).ToList())
        {
            _pendingCodes.Remove(code);
        }
    }

    private static string NewSessionToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
}
