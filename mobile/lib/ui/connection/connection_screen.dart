import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../network/wheeldeck_client.dart';
import '../../state/connection_coordinator.dart';

/// The entry point for getting phone and desktop onto the same WheelDeck
/// session: discover a server, or enter its address by hand, then pair and
/// connect.
///
/// Reads all of its dependencies from [ConnectionCoordinator] via the provider,
/// so it stays a pure stateless view and the coordinator owns all the
/// subscriptions.
class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<ConnectionCoordinator>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to WheelDeck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: coordinator.refreshDiscovery,
            tooltip: 'Refresh',
          ),
          if (coordinator.status != ConnectionStatus.disconnected)
            IconButton(
              icon: const Icon(Icons.wifi_off),
              onPressed: coordinator.disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          ConnectionStatusBanner(status: coordinator.status),
          const SizedBox(height: 16),
          if (coordinator.pairingChallenge != null)
            _PairingPrompt(coordinator: coordinator)
          else
            ..._buildDiscovery(context),
        ],
      ),
    );
  }

  List<Widget> _buildDiscovery(BuildContext context) {
    final coordinator = context.watch<ConnectionCoordinator>();

    return [
      Expanded(
        child: coordinator.servers.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                itemCount: coordinator.servers.length,
                itemBuilder: (context, index) {
                  final server = coordinator.servers[index];
                  return ListTile(
                    title: Text(server.name),
                    subtitle: Text('${server.host}:${server.port}'),
                    onTap: () =>
                        coordinator.connect(server.toConnectionTarget()),
                  );
                },
              ),
      ),
      const _ManualEntry(),
      const SizedBox(height: 16),
    ];
  }
}

/// The manual IP entry fallback; appears below the server list.
class _ManualEntry extends StatefulWidget {
  const _ManualEntry();

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  final _ip = TextEditingController();
  final _port = TextEditingController();

  @override
  void initState() {
    super.initState();
    final coordinator = context.read<ConnectionCoordinator>();
    _port.text = coordinator.defaultPort.toString();
    _ip.text = coordinator.defaultHost ?? '';
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<ConnectionCoordinator>();
    final canConnect =
        coordinator.status != ConnectionStatus.pairingRequired;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('manual-ip'),
              controller: _ip,
              decoration: const InputDecoration(labelText: 'IP address'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              key: const Key('manual-port'),
              controller: _port,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: canConnect ? _connect : null,
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _connect() {
    final ip = _ip.text;
    if (ip.isEmpty) return;
    final port = int.tryParse(_port.text);
    context.read<ConnectionCoordinator>().connectManual(
          host: ip,
          port: port,
        );
  }
}

/// PIN entry and QR-fallback prompt shown when the desktop requires pairing.
class _PairingPrompt extends StatefulWidget {
  const _PairingPrompt({required this.coordinator});

  final ConnectionCoordinator coordinator;

  @override
  State<_PairingPrompt> createState() => _PairingPromptState();
}

class _PairingPromptState extends State<_PairingPrompt> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.coordinator.pairingChallenge!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            challenge.method == PairingMethod.qrScan
                ? 'Scan the QR code displayed on your desktop.'
                : 'Enter the PIN shown on your desktop.',
          ),
          if (widget.coordinator.pairingError) ...[
            const SizedBox(height: 8),
            Text(
              'PIN incorrect. Try again.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (challenge.method == PairingMethod.pin) ...[
            TextField(
              key: const Key('pairing-pin'),
              controller: _pin,
              decoration: const InputDecoration(labelText: 'PIN'),
              keyboardType: TextInputType.number,
              obscureText: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Submit'),
            ),
          ],
        ],
      ),
    );
  }

  void _submit() {
    final code = _pin.text;
    if (code.isEmpty) return;
    widget.coordinator.submitPairingCode(code);
    _pin.clear();
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
