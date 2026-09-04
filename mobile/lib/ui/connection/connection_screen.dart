import 'package:flutter/material.dart';

import '../../network/discovery.dart';
import '../../network/pairing.dart';
import '../../network/wheeldeck_client.dart';

/// The entry point for getting phone and desktop onto the same WheelDeck
/// session: discover a server, or enter its address by hand, then pair and
/// connect.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    super.key,
    required this.discovery,
    required this.pairing,
  });

  final ServerDiscovery discovery;
  final PairingController pairing;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _ip = TextEditingController();
  final TextEditingController _pin = TextEditingController();

  List<DiscoveredServer> _servers = [];
  ConnectionStatus _status = ConnectionStatus.disconnected;
  bool _pairingRequired = false;

  @override
  void initState() {
    super.initState();

    widget.pairing.client
        .onConnectionStatusChanged((status) => setState(() => _status = status));
    widget.pairing.client
        .onPairingRequired((_) => setState(() => _pairingRequired = true));

    widget.discovery.discover().then((servers) {
      if (!mounted) return;
      setState(() => _servers = servers);
    });
  }

  @override
  void dispose() {
    _ip.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ConnectionStatusBanner(status: _status),
        const SizedBox(height: 24),
        if (_pairingRequired) ..._buildPairingPrompt(),
        if (!_pairingRequired) ..._buildDiscovery(),
      ],
    );
  }

  List<Widget> _buildPairingPrompt() {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Pairing Process: Enter the PIN shown on the desktop'),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          key: const Key('pairing-pin'),
          controller: _pin,
          decoration: const InputDecoration(labelText: 'PIN'),
          keyboardType: TextInputType.number,
          obscureText: true,
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: _submitPin,
          child: const Text('Submit'),
        ),
      ),
    ];
  }

  void _submitPin() {
    final code = _pin.text;
    if (code.isEmpty) return;
    widget.pairing.submitPairingCode(code);
    _pin.clear();
  }

  List<Widget> _buildDiscovery() {
    return [
      Expanded(
        child: _servers.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                itemCount: _servers.length,
                itemBuilder: (context, index) {
                  final server = _servers[index];
                  return ListTile(
                    title: Text(server.name),
                    subtitle: Text('${server.host}:${server.port}'),
                    onTap: () => _connect(server.toConnectionTarget()),
                  );
                },
              ),
      ),
      const _ManualEntry(),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _connect(ConnectionTarget target) async {
    await widget.pairing.restoreSession();
    widget.pairing.client.connect(target);
  }
}

/// The manual IP entry fallback; appears below the server list.
class _ManualEntry extends StatelessWidget {
  const _ManualEntry();

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_ConnectionScreenState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('manual-ip'),
              controller: screen?._ip,
              decoration: const InputDecoration(labelText: 'IP address'),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final ip = screen?._ip.text;
              if (ip == null || ip.isEmpty) return;
              screen?._connect(ConnectionTarget(
                  mode: ConnectionMode.manual, ipAddress: ip));
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No servers found. Enter an IP below.'));
  }
}

/// A one-line summary of the current connection state.
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key, required this.status});

  final ConnectionStatus status;

  String get label {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting…';
      case ConnectionStatus.pairingRequired:
        return 'Pairing required';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting…';
      case ConnectionStatus.discovering:
        return 'Searching…';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
