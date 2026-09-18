import 'package:flutter/material.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/controller_preset.dart';
import '../../../../data/services/controller_visibility.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_visibility.dart';
import '../../../../data/services/engine_start_mode.dart';
import '../../../../data/services/input_mapping.dart';
import '../../../../data/services/pedal_input.dart';
import '../../../../data/services/pedal_side.dart';
import '../../../../data/services/wheel_mode.dart';
import '../../../../ui/core/connection_coordinator.dart';
import '../view_models/settings_view_model.dart';
import 'binding_edit_dialog.dart';

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
        content: const Text('This will restore keyboard, rotatable 900°, hidden clutch, shown dashboard, and default pedal sides.'),
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

              // Wheel mode
              Text('Wheel mode', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SegmentedButton<WheelMode>(
                segments: [
                  ButtonSegment(
                      value: WheelMode.rotatable,
                      label: Text(WheelMode.rotatable.label)),
                  ButtonSegment(
                      value: WheelMode.gyro,
                      label: Text(WheelMode.gyro.label)),
                ],
                selected: {_viewModel.wheelMode},
                onSelectionChanged: (s) => _viewModel.selectWheelMode(s.first),
              ),
              const SizedBox(height: 12),
              if (_viewModel.wheelMode == WheelMode.rotatable) ...[
                Text('Rotation degrees',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final degree in RotationDegree.allowed)
                      ChoiceChip(
                        label: Text('$degree°'),
                        selected: _viewModel.rotationDegree == degree,
                        onSelected: (_) =>
                            _viewModel.selectRotationDegree(degree),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Finger rotation for full lock-to-lock.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ] else
                Text('Gyro steering ignores rotation degrees.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),

              // Controller visibility
              Text('Show controls', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Clutch pedal', style: TextStyle(fontSize: 14)),
                      value: _viewModel.visibility.showClutch,
                      onChanged: (v) => _viewModel.selectVisibility(
                        ControllerVisibility(
                          showClutch: v,
                          showDashboard: _viewModel.visibility.showDashboard,
                        ),
                      ),
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text('Dashboard', style: TextStyle(fontSize: 14)),
                      value: _viewModel.visibility.showDashboard,
                      onChanged: (v) => _viewModel.selectVisibility(
                        ControllerVisibility(
                          showClutch: _viewModel.visibility.showClutch,
                          showDashboard: v,
                        ),
                      ),
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pedal sides
              Text('Pedal sides', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final pedal in PedalType.values)
                      ListTile(
                        dense: true,
                        title: Text(_pedalLabel(pedal), style: const TextStyle(fontSize: 14)),
                        trailing: SegmentedButton<PedalSide>(
                          segments: const [
                            ButtonSegment(value: PedalSide.left, label: Text('Left')),
                            ButtonSegment(value: PedalSide.right, label: Text('Right')),
                          ],
                          selected: {_viewModel.pedalSides[pedal] ?? PedalSide.right},
                          onSelectionChanged: (s) =>
                              _viewModel.selectPedalSide(pedal, s.first),
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Engine start mode
              Text('Engine start', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SegmentedButton<EngineStartMode>(
                segments: const [
                  ButtonSegment(value: EngineStartMode.holdConfirm, label: Text('Hold to confirm')),
                  ButtonSegment(value: EngineStartMode.singlePress, label: Text('Single press')),
                ],
                selected: {_viewModel.engineStartMode},
                onSelectionChanged: (s) =>
                    _viewModel.selectEngineStartMode(s.first),
              ),
              const SizedBox(height: 24),

              // Dashboard controls
              Text('Dashboard controls', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final c in DashboardVisibility.toggleable)
                      SwitchListTile(
                        title: Text(_controlLabel(c), style: const TextStyle(fontSize: 14)),
                        value: _viewModel.visibleExtras.contains(c),
                        onChanged: (_) => _viewModel.toggleExtraControl(c),
                        dense: true,
                      ),
                  ],
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

  String _pedalLabel(PedalType p) {
    switch (p) {
      case PedalType.accelerator:
        return 'Accelerator';
      case PedalType.brake:
        return 'Brake';
      case PedalType.clutch:
        return 'Clutch';
    }
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
      case ControlId.lightsOff:
        return 'Lights off';
      case ControlId.lightsParking:
        return 'Lights parking';
      case ControlId.lightsLowbeam:
        return 'Lights low beam';
      case ControlId.highBeamToggle:
        return 'High-beam';
      case ControlId.wipers:
        return 'Wipers';
      case ControlId.cruiseToggle:
        return 'Cruise toggle';
      case ControlId.cruiseSetResume:
        return 'Cruise resume';
      case ControlId.engineStart:
        return 'Engine start';
      case ControlId.hazardLights:
        return 'Hazard lights';
      case ControlId.beaconLights:
        return 'Beacon lights';
      case ControlId.flasher:
        return 'Flasher';
      case ControlId.horn:
        return 'Horn';
      case ControlId.trailer:
        return 'Trailer';
      case ControlId.liftDropAxle:
        return 'Lift/drop axle';
      case ControlId.cameraView:
        return 'Camera view';
      case ControlId.gearUp:
        return 'Gear up';
      case ControlId.gearDown:
        return 'Gear down';
      case ControlId.engineBrake:
        return 'Engine brake';
      case ControlId.airHorn:
        return 'Air horn';
      case ControlId.differentialLock:
        return 'Differential lock';
      case ControlId.retarderIncrease:
        return 'Retarder +';
      case ControlId.retarderDecrease:
        return 'Retarder -';
      case ControlId.quickInfo:
        return 'Quick info';
      case ControlId.mirrorToggle:
        return 'Mirror';
      case ControlId.hudWidgets:
        return 'HUD widgets';
      case ControlId.vehicleAdjustment:
        return 'Vehicle adjustment';
      case ControlId.navigationZoomOut:
        return 'Nav zoom out';
      case ControlId.widgetOptions:
        return 'Widget options';
      case ControlId.services:
        return 'Services';
      case ControlId.quickSave:
        return 'Quick save';
      case ControlId.quickLoad:
        return 'Quick load';
      case ControlId.screenshot:
        return 'Screenshot';
      case ControlId.garageManager:
        return 'Garage';
      case ControlId.audioPlayer:
        return 'Audio player';
      case ControlId.shiftToDrive:
        return 'Shift to drive';
      case ControlId.shiftToReverse:
        return 'Shift to reverse';
      case ControlId.shiftToNeutral:
        return 'Shift to neutral';
      case ControlId.engineElectricity:
        return 'Engine electricity';
      case ControlId.adaptiveCruise:
        return 'Adaptive cruise';
      case ControlId.cruiseSpeedIncrease:
        return 'Cruise speed +';
      case ControlId.cruiseSpeedDecrease:
        return 'Cruise speed -';
      case ControlId.laneAssistant:
        return 'Lane assistant';
      case ControlId.laneKeeping:
        return 'Lane keeping';
      case ControlId.emergencyBrake:
        return 'Emergency brake';
      case ControlId.wipersBack:
        return 'Wipers back';
      case ControlId.audioPlayPause:
        return 'Audio play/pause';
      case ControlId.audioNext:
        return 'Audio next';
      case ControlId.audioPrevious:
        return 'Audio previous';
      case ControlId.audioVolumeUp:
        return 'Audio vol +';
      case ControlId.audioVolumeDown:
        return 'Audio vol -';
      case ControlId.audioFavorite:
        return 'Audio favorite';
      case ControlId.cameraPadUp:
        return 'Camera up';
      case ControlId.cameraPadDown:
        return 'Camera down';
      case ControlId.cameraPadLeft:
        return 'Camera left';
      case ControlId.cameraPadRight:
        return 'Camera right';
      case ControlId.cameraPadUpLeft:
        return 'Camera up-left';
      case ControlId.cameraPadUpRight:
        return 'Camera up-right';
      case ControlId.cameraPadDownLeft:
        return 'Camera down-left';
      case ControlId.cameraPadDownRight:
        return 'Camera down-right';
      case ControlId.cameraPadRecenter:
        return 'Recenter camera';
      case ControlId.cameraPadArrowUp:
        return 'Camera arrow up';
      case ControlId.cameraPadArrowDown:
        return 'Camera arrow down';
      case ControlId.cameraPadArrowLeft:
        return 'Camera arrow left';
      case ControlId.cameraPadArrowRight:
        return 'Camera arrow right';
    }
  }

  void _editBinding(ControlId c, String current, bool isGamepad) {
    BindingEditDialog.show(
      context,
      title: _controlLabel(c),
      current: current,
      isGamepad: isGamepad,
      onSave: (value) async {
        await _viewModel.setBinding(c, value);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_controlLabel(c)} → $value')),
          );
        }
      },
    );
  }
}
