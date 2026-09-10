import 'package:flutter/material.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/controller_preset.dart';
import '../../../../data/services/controller_type.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/input_mapping.dart';
import '../../../../data/services/pedal_layout.dart';
import '../../../../ui/core/connection_coordinator.dart';
import '../view_models/settings_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.coordinator, this.viewModel});

  final ConnectionCoordinator coordinator;
  final SettingsViewModel? viewModel;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    final override = widget.viewModel;
    if (override != null) {
      _viewModel = override;
      _ownsViewModel = false;
    } else {
      _viewModel = SettingsViewModel(
        settingsRepository: const SettingsRepository(),
        connectionRepository: widget.coordinator.connectionRepository,
      );
      _ownsViewModel = true;
      _viewModel.init();
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset to defaults?'),
        content: const Text('This will restore keyboard, full controller, and layout A.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) {
      await _viewModel.resetToDefaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset to defaults')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (!_viewModel.loaded) return const Center(child: CircularProgressIndicator());
          final cs = Theme.of(context).colorScheme;
          final isGamepad = _viewModel.mapping == InputMapping.gamepad;

          return SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              // Input mapping
              Text('Input mode', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SegmentedButton<InputMapping>(
                segments: const [
                  ButtonSegment(value: InputMapping.keyboard, label: Text('Keyboard'), icon: Icon(Icons.keyboard)),
                  ButtonSegment(value: InputMapping.gamepad, label: Text('Gamepad'), icon: Icon(Icons.sports_esports)),
                ],
                selected: {_viewModel.mapping},
                onSelectionChanged: (s) => _viewModel.select(s.first),
              ),
              const SizedBox(height: 4),
              Text(isGamepad ? 'Dashboard → virtual controller buttons' : 'Dashboard → ETS2 keybindings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),

              // Game preset
              Text('Game preset', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SegmentedButton<GamePreset>(
                segments: const [
                  ButtonSegment(value: GamePreset.ets2, label: Text('ETS2')),
                  ButtonSegment(value: GamePreset.generic, label: Text('Generic')),
                ],
                selected: {_viewModel.preset},
                onSelectionChanged: (s) => _viewModel.selectPreset(s.first),
              ),
              const SizedBox(height: 24),

              // Controller type
              Text('Controller type', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: RadioGroup<ControllerType>(
                  groupValue: _viewModel.controllerType,
                  onChanged: (v) => v != null ? _viewModel.selectControllerType(v) : null,
                  child: Column(
                    children: ControllerType.values.map((t) {
                      return RadioListTile<ControllerType>(
                        title: Text(t.label),
                        value: t,
                        dense: true,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Pedal layout
              Text('Pedal layout', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: RadioGroup<PedalLayout>(
                  groupValue: _viewModel.pedalLayout,
                  onChanged: (v) => v != null ? _viewModel.selectPedalLayout(v) : null,
                  child: Column(
                    children: PedalLayout.values.map((l) {
                      return RadioListTile<PedalLayout>(
                        title: Text(l.label, style: const TextStyle(fontSize: 14)),
                        value: l,
                        dense: true,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Per-control bindings
              Text('Button bindings (${isGamepad ? 'gamepad' : 'keyboard'})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: ControlId.values.map((c) {
                    final binding = _viewModel.bindingFor(c);
                    return ListTile(
                      dense: true,
                      title: Text(_controlLabel(c), style: const TextStyle(fontSize: 14)),
                      trailing: Chip(
                        label: Text(binding, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onTap: () => _editBinding(c, binding, isGamepad),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text('Tap a control to customize (ETS2 preset shown).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 32),

              // Reset
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmReset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset to default'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 24),
            ],
            ),
          );
        },
      ),
    );
  }

  String _controlLabel(ControlId c) {
    switch (c) {
      case ControlId.parkingBrake:
        return 'Parking brake';
      case ControlId.turnSignalLeft:
        return 'Turn signal L';
      case ControlId.turnSignalRight:
        return 'Turn signal R';
      case ControlId.headlightToggle:
        return 'Headlights';
      case ControlId.highBeamToggle:
        return 'High beam';
      case ControlId.wipers:
        return 'Wipers';
      case ControlId.cruiseToggle:
        return 'Cruise toggle';
      case ControlId.cruiseSetResume:
        return 'Cruise set/resume';
      case ControlId.engineStart:
        return 'Engine start';
    }
  }

  void _editBinding(ControlId c, String current, bool isGamepad) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${_controlLabel(c)}'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: isGamepad ? 'Button' : 'Key', border: const OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final value = ctrl.text.trim();
              Navigator.pop(ctx);
              await _viewModel.setBinding(c, value);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${_controlLabel(c)} → $value')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
