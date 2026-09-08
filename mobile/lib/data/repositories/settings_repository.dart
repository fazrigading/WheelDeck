import '../../input/input_mapping.dart';

/// Single source of truth for the dashboard input mapping choice.
///
/// Wraps the persisted [InputMapping] so the settings flow never touches
/// storage directly. Forwarding the choice to the desktop stays in
/// [ConnectionRepository.sendMappingMode].
class SettingsRepository {
  const SettingsRepository();

  /// Loads the persisted mapping, defaulting to keyboard.
  Future<InputMapping> getMapping() => InputMapping.load();

  /// Persists the mapping.
  Future<void> setMapping(InputMapping mapping) => mapping.save();
}
