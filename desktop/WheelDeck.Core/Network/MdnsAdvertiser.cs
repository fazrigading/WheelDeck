using System.Net;
using System.Net.Sockets;
using System.Text;

namespace WheelDeck.Core.Network;

/// <summary>
/// Announces the WheelDeck desktop on the LAN via mDNS so the phone's server
/// list populates. Answers PTR/SRV/TXT/A queries for
/// <c>_wheeldeck._tcp.local</c> on 224.0.0.251:5353 and re-announces
/// periodically. Best effort: failures never take down the server.
/// </summary>
public sealed class MdnsAdvertiser : IDisposable
{
    public const string ServiceType = "_wheeldeck._tcp.local";

    private const string MulticastAddress = "224.0.0.251";
    private const int MdnsPort = 5353;
    private const uint Ttl = 120;

    private readonly int _port;
    private readonly string _instanceName;
    private readonly string _hostName;

    private UdpClient? _udp;
    private Timer? _announceTimer;
    private CancellationTokenSource? _cts;
    private bool _disposed;

    public MdnsAdvertiser(int port = WebSocketListener.DefaultPort)
    {
        _port = port;
        var machine = Environment.MachineName.Trim();
        if (string.IsNullOrWhiteSpace(machine))
        {
            machine = "WheelDeck";
        }

        _hostName = $"{machine}.local";
        _instanceName = $"{machine}.{ServiceType}";
    }

    /// <summary>Joins the mDNS group, answers queries, and announces once.</summary>
    public void Start()
    {
        if (_udp is not null)
        {
            return;
        }

        try
        {
            var udp = new UdpClient();
            udp.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            udp.Client.Bind(new IPEndPoint(IPAddress.Any, MdnsPort));
            udp.JoinMulticastGroup(IPAddress.Parse(MulticastAddress));
            _udp = udp;
        }
        catch
        {
            // No multicast on this network; the manual-IP fallback still works.
            return;
        }

        _cts = new CancellationTokenSource();
        _ = Task.Run(() => ReceiveLoopAsync(_cts.Token), CancellationToken.None);
        Announce();
        _announceTimer = new Timer(_ => Announce(), null, TimeSpan.FromSeconds(60), TimeSpan.FromSeconds(60));
    }

    public void Stop()
    {
        _announceTimer?.Dispose();
        _announceTimer = null;
        try
        {
            _cts?.Cancel();
        }
        catch
        {
        }

        _cts?.Dispose();
        _cts = null;
        _udp?.Dispose();
        _udp = null;
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        Stop();
    }

    private async Task ReceiveLoopAsync(CancellationToken ct)
    {
        var udp = _udp;
        if (udp is null)
        {
            return;
        }

        while (!ct.IsCancellationRequested)
        {
            UdpReceiveResult result;
            try
            {
                result = await udp.ReceiveAsync(ct).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch
            {
                break;
            }

            try
            {
                var response = BuildResponse(result.Buffer);
                if (response is not null)
                {
                    await udp.SendAsync(response, new IPEndPoint(IPAddress.Parse(MulticastAddress), MdnsPort), ct)
                        .ConfigureAwait(false);
                }
            }
            catch
            {
                // A malformed query must not kill the responder.
            }
        }
    }

    private void Announce()
    {
        var udp = _udp;
        if (udp is null)
        {
            return;
        }

        try
        {
            var response = BuildAnnouncement();
            udp.Send(response, response.Length, new IPEndPoint(IPAddress.Parse(MulticastAddress), MdnsPort));
        }
        catch
        {
        }
    }

    private byte[] BuildAnnouncement()
    {
        var writer = new DnsWriter();
        writer.WriteHeader(id: 0, flags: 0x8400, qdCount: 0, anCount: 4);
        writer.WritePtr(ServiceType, _instanceName, Ttl);
        writer.WriteSrv(_instanceName, _hostName, (ushort)_port, Ttl);
        writer.WriteTxt(_instanceName, Ttl);
        if (TryLocalIp(out var ip))
        {
            writer.WriteA(_hostName, ip, Ttl);
        }

        return writer.ToArray();
    }

    private byte[]? BuildResponse(byte[] query)
    {
        if (query.Length < 12)
        {
            return null;
        }

        var flags = (ushort)((query[2] << 8) | query[3]);
        if ((flags & 0x8000) != 0)
        {
            return null; // Ignore responses.
        }

        var qdCount = (query[4] << 8) | query[5];
        var offset = 12;
        ReplyKind reply = ReplyKind.None;

        for (var i = 0; i < qdCount; i++)
        {
            if (!TryReadName(query, ref offset, out var name))
            {
                return null;
            }

            if (offset + 4 > query.Length)
            {
                return null;
            }

            var qtype = (query[offset] << 8) | query[offset + 1];
            offset += 4;

            reply |= Classify(name, qtype);
        }

        if (reply == ReplyKind.None)
        {
            return null;
        }

        var w = new DnsWriter();
        var hasIp = TryLocalIp(out var ip);
        var anCount = 0;
        // Size up the answer count before writing.
        if (reply.HasFlag(ReplyKind.Ptr))
        {
            anCount += 1;
        }

        if (reply.HasFlag(ReplyKind.Srv))
        {
            anCount += 2; // SRV + TXT travel together.
        }

        if (reply.HasFlag(ReplyKind.Address) && hasIp)
        {
            anCount += 1;
        }

        w.WriteHeader(id: 0, flags: 0x8400, qdCount: 0, anCount: (ushort)anCount);
        if (reply.HasFlag(ReplyKind.Ptr))
        {
            w.WritePtr(ServiceType, _instanceName, Ttl);
        }

        if (reply.HasFlag(ReplyKind.Srv))
        {
            w.WriteSrv(_instanceName, _hostName, (ushort)_port, Ttl);
            w.WriteTxt(_instanceName, Ttl);
        }

        if (reply.HasFlag(ReplyKind.Address) && hasIp)
        {
            w.WriteA(_hostName, ip, Ttl);
        }

        return w.ToArray();
    }

    private ReplyKind Classify(string name, int qtype)
    {
        var any = qtype == 255;
        if ((qtype == 12 || any) && Matches(name, ServiceType))
        {
            return ReplyKind.Ptr | ReplyKind.Srv | ReplyKind.Address;
        }

        if ((qtype == 33 || any) && Matches(name, _instanceName))
        {
            return ReplyKind.Srv | ReplyKind.Address;
        }

        if ((qtype == 1 || any) && Matches(name, _hostName))
        {
            return ReplyKind.Address;
        }

        return ReplyKind.None;
    }

    private static bool Matches(string a, string b) =>
        string.Equals(a.TrimEnd('.'), b.TrimEnd('.'), StringComparison.OrdinalIgnoreCase);

    private static bool TryReadName(byte[] buffer, ref int offset, out string name)
    {
        var labels = new List<string>();
        var jumped = false;
        var guard = 0;

        while (true)
        {
            if (offset >= buffer.Length || guard++ > 64)
            {
                name = string.Empty;
                return false;
            }

            var length = buffer[offset++];
            if (length == 0)
            {
                break;
            }

            if ((length & 0xC0) == 0xC0)
            {
                if (offset >= buffer.Length)
                {
                    name = string.Empty;
                    return false;
                }

                var pointer = ((length & 0x3F) << 8) | buffer[offset];
                if (!jumped)
                {
                    offset += 1;
                    jumped = true;
                }

                var inner = pointer;
                if (!TryReadName(buffer, ref inner, out var pointed))
                {
                    name = string.Empty;
                    return false;
                }

                labels.Add(pointed);
                break;
            }

            if (offset + length > buffer.Length)
            {
                name = string.Empty;
                return false;
            }

            labels.Add(Encoding.UTF8.GetString(buffer, offset, length));
            offset += length;
        }

        name = string.Join(".", labels);
        return true;
    }

    private static bool TryLocalIp(out IPAddress ip)
    {
        var text = NetworkHelper.GetLocalIpAddress();
        return IPAddress.TryParse(text, out ip!);
    }

    [Flags]
    private enum ReplyKind
    {
        None = 0,
        Ptr = 1,
        Srv = 2,
        Address = 4
    }

    private sealed class DnsWriter
    {
        private readonly MemoryStream _stream = new();

        public byte[] ToArray() => _stream.ToArray();

        public void WriteHeader(ushort id, ushort flags, ushort qdCount, ushort anCount)
        {
            WriteU16(id);
            WriteU16(flags);
            WriteU16(qdCount);
            WriteU16(anCount);
            WriteU16(0); // NSCOUNT
            WriteU16(0); // ARCOUNT
        }

        public void WritePtr(string name, string target, uint ttl)
        {
            WriteName(name);
            WriteU16(12); // PTR
            WriteU16(1); // IN
            WriteU32(ttl);
            var targetBytes = EncodeName(target);
            WriteU16((ushort)targetBytes.Length);
            _stream.Write(targetBytes, 0, targetBytes.Length);
        }

        public void WriteSrv(string name, string target, ushort port, uint ttl)
        {
            WriteName(name);
            WriteU16(33); // SRV
            WriteU16(1); // IN
            WriteU32(ttl);
            var targetBytes = EncodeName(target);
            WriteU16((ushort)(6 + targetBytes.Length));
            WriteU16(0); // priority
            WriteU16(0); // weight
            WriteU16(port);
            _stream.Write(targetBytes, 0, targetBytes.Length);
        }

        public void WriteTxt(string name, uint ttl)
        {
            WriteName(name);
            WriteU16(16); // TXT
            WriteU16(1); // IN
            WriteU32(ttl);
            WriteU16(1); // one empty string
            _stream.WriteByte(0);
        }

        public void WriteA(string name, IPAddress address, uint ttl)
        {
            WriteName(name);
            WriteU16(1); // A
            WriteU16(1); // IN
            WriteU32(ttl);
            var bytes = address.GetAddressBytes();
            WriteU16((ushort)bytes.Length);
            _stream.Write(bytes, 0, bytes.Length);
        }

        private void WriteName(string name)
        {
            var bytes = EncodeName(name);
            _stream.Write(bytes, 0, bytes.Length);
        }

        private static byte[] EncodeName(string name)
        {
            using var ms = new MemoryStream();
            foreach (var label in name.TrimEnd('.').Split('.'))
            {
                var bytes = Encoding.UTF8.GetBytes(label);
                ms.WriteByte((byte)bytes.Length);
                ms.Write(bytes, 0, bytes.Length);
            }

            ms.WriteByte(0);
            return ms.ToArray();
        }

        private void WriteU16(ushort value)
        {
            _stream.WriteByte((byte)(value >> 8));
            _stream.WriteByte((byte)(value & 0xFF));
        }

        private void WriteU32(uint value)
        {
            _stream.WriteByte((byte)(value >> 24));
            _stream.WriteByte((byte)((value >> 16) & 0xFF));
            _stream.WriteByte((byte)((value >> 8) & 0xFF));
            _stream.WriteByte((byte)(value & 0xFF));
        }
    }
}
