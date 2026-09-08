import 'package:flutter/material.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/input_mapping.dart';
import '../../../../ui/core/connection_coordinator.dart';
import '../view_models/settings_view_model.dart';

/// Options page: dashboard input mapping (keyboard or gamepad).
///
/// Lean widget: the choice lives in [SettingsViewModel], which persists it
/// through [SettingsRepository] and forwards it to the desktop. The desktop
/// routes dashboard buttons to simulated key presses or controller buttons.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.coordinator, this.viewModel});

  final ConnectionCoordinator coordinator;

  /// Override for tests. When omitted, the state builds a live view model
  /// from the coordinator's connection repository.
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
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (!_viewModel.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Dashboard buttons act as:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              RadioGroup<InputMapping>(
                groupValue: _viewModel.mapping,
                onChanged: (m) => m != null ? _viewModel.select(m) : null,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Keyboard keys'),
                      subtitle:
                          const Text('ETS2 default keybindings (Space, L, K …)'),
                      leading:
                          const Radio<InputMapping>(value: InputMapping.keyboard),
                      onTap: () => _viewModel.select(InputMapping.keyboard),
                    ),
                    ListTile(
                      title: const Text('Gamepad buttons'),
                      subtitle: const Text(
                          'Virtual-controller buttons (A, B, D-pad …)'),
                      leading:
                          const Radio<InputMapping>(value: InputMapping.gamepad),
                      onTap: () => _viewModel.select(InputMapping.gamepad),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
