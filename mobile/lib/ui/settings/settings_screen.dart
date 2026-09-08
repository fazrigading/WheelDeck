import 'package:flutter/material.dart';

import '../../input/input_mapping.dart';
import '../../network/wheeldeck_client.dart';

/// Options page: dashboard input mapping (keyboard or gamepad).
///
/// Persists the choice locally and forwards it to the desktop, which routes
/// dashboard buttons to simulated key presses or controller buttons.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.client});

  final WheelDeckClient client;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  InputMapping _mapping = InputMapping.keyboard;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    InputMapping.load().then((mapping) {
      if (mounted) {
        setState(() {
          _mapping = mapping;
          _loaded = true;
        });
      }
    });
  }

  Future<void> _select(InputMapping mapping) async {
    setState(() => _mapping = mapping);
    await mapping.save();
    widget.client.sendMappingMode(mapping);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Dashboard buttons act as:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                RadioGroup<InputMapping>(
                  groupValue: _mapping,
                  onChanged: (m) => m != null ? _select(m) : null,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Keyboard keys'),
                        subtitle: const Text('ETS2 default keybindings (Space, L, K …)'),
                        leading: const Radio<InputMapping>(value: InputMapping.keyboard),
                        onTap: () => _select(InputMapping.keyboard),
                      ),
                      ListTile(
                        title: const Text('Gamepad buttons'),
                        subtitle: const Text('Virtual-controller buttons (A, B, D-pad …)'),
                        leading: const Radio<InputMapping>(value: InputMapping.gamepad),
                        onTap: () => _select(InputMapping.gamepad),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
