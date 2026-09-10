import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/connection_coordinator.dart';

/// M3 bottom sheet for manual IP + Port entry. Inputs filtered to numbers/dot.
class ManualAddSheet extends StatefulWidget {
  const ManualAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const ManualAddSheet(),
    );
  }

  @override
  State<ManualAddSheet> createState() => _ManualAddSheetState();
}

class _ManualAddSheetState extends State<ManualAddSheet> {
  final _ip = TextEditingController();
  final _port = TextEditingController();
  String? _ipError;

  static final _ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  @override
  void initState() {
    super.initState();
    final c = context.read<ConnectionCoordinator>();
    _port.text = c.defaultPort.toString();
    _ip.text = c.defaultHost ?? '';
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  bool _validate() {
    final ip = _ip.text.trim();
    if (ip.isEmpty) {
      setState(() => _ipError = 'IP required');
      return false;
    }
    if (!_ipRegex.hasMatch(ip)) {
      // Allow loose check: at least contains numbers and dots, M3 shows hint
      // For strictness, require 4 octets. Skip strict if user typing incomplete.
      // We enforce on submit only if fully formed.
      if (ip.split('.').length != 4) {
        setState(() => _ipError = 'Enter valid IP (e.g. 192.168.1.10)');
        return false;
      }
    }
    // Octet range check
    for (final part in ip.split('.')) {
      final v = int.tryParse(part);
      if (v == null || v < 0 || v > 255) {
        setState(() => _ipError = 'Each octet 0-255');
        return false;
      }
    }
    setState(() => _ipError = null);
    return true;
  }

  void _connect() {
    if (!_validate()) return;
    final ip = _ip.text.trim();
    final port = int.tryParse(_port.text.trim());
    // Close sheet first for snappy feel
    Navigator.of(context).pop();
    context.read<ConnectionCoordinator>().connectManual(host: ip, port: port);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 8, bottom: bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add receiver manually',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Enter the desktop IP shown on the desktop app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 24),
          TextField(
            key: const Key('manual-ip'),
            controller: _ip,
            decoration: InputDecoration(
              labelText: 'IP address',
              hintText: '192.168.1.10',
              errorText: _ipError,
              prefixIcon: const Icon(Icons.language),
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) {
              if (_ipError != null) setState(() => _ipError = null);
            },
            onSubmitted: (_) => _connect(),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('manual-port'),
            controller: _port,
            decoration: const InputDecoration(
              labelText: 'Port',
              prefixIcon: Icon(Icons.tag),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.wifi),
              label: const Text('Connect'),
            ),
          ),
        ],
      ),
    );
  }
}
