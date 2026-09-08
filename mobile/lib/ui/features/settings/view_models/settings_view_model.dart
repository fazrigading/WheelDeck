import 'package:flutter/foundation.dart';

import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/input_mapping.dart';

/// Presentation state for the settings page.
///
/// Injects [SettingsRepository] (persisted choice) and [ConnectionRepository]
/// (forwards the choice to the desktop). The View renders via
/// `ListenableBuilder`.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsRepository settingsRepository,
    required ConnectionRepository connectionRepository,
  })  : _settingsRepository = settingsRepository,
        _connectionRepository = connectionRepository;

  final SettingsRepository _settingsRepository;
  final ConnectionRepository _connectionRepository;

  InputMapping _mapping = InputMapping.keyboard;
  bool _loaded = false;

  InputMapping get mapping => _mapping;
  bool get loaded => _loaded;

  /// Loads the persisted mapping. Best-effort: falls back to the default
  /// instead of stranding the page on a spinner.
  Future<void> init() async {
    try {
      _mapping = await _settingsRepository.getMapping();
    } catch (_) {
      // Ignore: keep the default when storage is unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persists the choice and forwards it to the desktop.
  Future<void> select(InputMapping mapping) async {
    _mapping = mapping;
    notifyListeners();
    await _settingsRepository.setMapping(mapping);
    _connectionRepository.sendMappingMode(mapping);
  }
}
