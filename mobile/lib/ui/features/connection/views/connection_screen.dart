import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/connection_status.dart';
import '../../../../domain/models/pairing_method.dart';
import '../../../../ui/core/connection_coordinator.dart';
import '../../settings/views/settings_screen.dart';
import 'manual_add_sheet.dart';

/// M3 Connect screen: status card, paired/unpaired split, FAB manual add.
class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<ConnectionCoordinator>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to WheelDeck'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(coordinator: coordinator),
              ),
            ),
            tooltip: 'Settings',
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.refresh),
            onPressed: coordinator.refreshDiscovery,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          if (coordinator.status != ConnectionStatus.disconnected)
            IconButton(
              icon: const Icon(Icons.wifi_off),
              onPressed: coordinator.disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      floatingActionButton: coordinator.pairingChallenge == null
          ? FloatingActionButton.extended(
              key: const Key('manual-add-fab'),
              onPressed: () => ManualAddSheet.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Add IP'),
              tooltip: 'Add receiver manually',
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConnectionStatusCard(status: coordinator.status),
          ),
          if (coordinator.status == ConnectionStatus.connected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('ready-to-drive'),
                  onPressed: () {
                    // Pop the pushed ConnectionScreen to reveal DrivingView
                    // which _Routing already shows when status==connected.
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.sports_motorsports),
                  label: const Text('Ready to Drive'),
                ),
              ),
            ),
          if (coordinator.status == ConnectionStatus.reconnecting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Connection unsuccessful. Check that the desktop app is running '
                'and both devices are on the same Wi-Fi, or tap Add IP below.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
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
    final paired = coordinator.pairedServers;
    final unpaired = coordinator.unpairedServers;
    final hasAny = coordinator.servers.isNotEmpty;

    if (!hasAny) {
      return const [
        Expanded(child: _EmptyState()),
        SizedBox(height: 80), // FAB clearance
      ];
    }

    return [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (paired.isNotEmpty) ...[
              _SectionHeader(icon: Icons.history, label: 'Paired devices'),
              const SizedBox(height: 8),
              for (final s in paired)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.computer,
                          color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.host}:${s.port}\nTap to reconnect'),
                    isThreeLine: true,
                    trailing: Icon(Icons.verified,
                        color: Theme.of(context).colorScheme.primary, size: 20),
                    onTap: () => coordinator.connect(s.toConnectionTarget()),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            _SectionHeader(
              icon: Icons.wifi_find,
              label: paired.isNotEmpty ? 'Available on this Wi-Fi' : 'Receivers on this Wi-Fi',
            ),
            const SizedBox(height: 8),
            if (unpaired.isEmpty && paired.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No new receivers found.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              )
            else
              for (final s in unpaired)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.computer,
                          color: Theme.of(context).colorScheme.onSecondaryContainer),
                    ),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.host}:${s.port}\nTap to connect – PIN required'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => coordinator.connect(s.toConnectionTarget()),
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 80),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}

/// M3 status card — tinted by status role, progress for transient states.
/// Peak-end: connected shows bounce + sparkle.
class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({super.key, required this.status});
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

  IconData get icon {
    switch (status) {
      case ConnectionStatus.connected:
        return Icons.wifi;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
      case ConnectionStatus.discovering:
        return Icons.sync;
      case ConnectionStatus.pairingRequired:
        return Icons.key;
      case ConnectionStatus.disconnected:
        return Icons.wifi_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTransient = status == ConnectionStatus.connecting ||
        status == ConnectionStatus.reconnecting ||
        status == ConnectionStatus.discovering;

    Color bg;
    Color fg;
    Color iconBg;
    switch (status) {
      case ConnectionStatus.connected:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        iconBg = cs.primary;
        break;
      case ConnectionStatus.pairingRequired:
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        iconBg = cs.tertiary;
        break;
      case ConnectionStatus.reconnecting:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        iconBg = cs.error;
        break;
      case ConnectionStatus.disconnected:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        iconBg = cs.outline;
        break;
      default:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        iconBg = cs.secondary;
    }

    final isConnected = status == ConnectionStatus.connected;

    Widget leading = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: iconBg.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 22),
    );
    if (isConnected) {
      leading = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            leading,
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                child: Icon(Icons.auto_awesome, size: 8, color: bg),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isConnected
            ? [BoxShadow(color: iconBg.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 1)]
            : null,
      ),
      child: Card(
        color: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: fg)),
                    Text(_subtitle(status), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              if (isTransient) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
              if (isConnected)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Icon(Icons.check_circle, color: fg, size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return 'Ready to drive';
      case ConnectionStatus.connecting:
        return 'Establishing link…';
      case ConnectionStatus.pairingRequired:
        return 'Enter PIN to pair';
      case ConnectionStatus.reconnecting:
        return 'Trying again…';
      case ConnectionStatus.discovering:
        return 'Scanning local network…';
      case ConnectionStatus.disconnected:
        return 'Tap a receiver or add IP';
    }
  }
}

/// Back-compat alias for tests that look for ConnectionStatusBanner.
typedef ConnectionStatusBanner = ConnectionStatusCard;

/// PIN entry and QR-fallback prompt.
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          if (challenge.method == PairingMethod.pin) ...[
            TextField(
              key: const Key('pairing-pin'),
              controller: _pin,
              decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              obscureText: false,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Submit'),
              ),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.search_off, size: 40, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text('No receivers found', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Make sure the desktop app is running\non the same Wi-Fi.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.read<ConnectionCoordinator>().refreshDiscovery(),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan again'),
            ),
          ],
        ),
      ),
    );
  }
}
