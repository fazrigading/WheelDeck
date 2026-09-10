import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/discovered_server.dart';

/// Persists paired device ids (`host:port`) so Connect can split paired vs new.
class PairedDeviceRepository {
  PairedDeviceRepository({this.prefsKey = _defaultKey, this.loader, this.saver});

  static const String _defaultKey = 'wheeldeck.paired_devices';

  final String prefsKey;
  final Future<List<String>> Function()? loader;
  final Future<void> Function(List<String> ids)? saver;

  Future<List<String>> _loadIds() async {
    if (loader != null) return loader!.call();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(prefsKey) ?? const [];
  }

  Future<void> _saveIds(List<String> ids) async {
    if (saver != null) return saver!.call(ids);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefsKey, ids);
  }

  static String idOf(DiscoveredServer s) => '${s.host}:${s.port}';
  static String idOfHostPort(String host, int port) => '$host:$port';

  Future<List<String>> load() => _loadIds();

  Future<bool> isPaired(DiscoveredServer s) async {
    final ids = await _loadIds();
    return ids.contains(idOf(s));
  }

  /// Adds `host:port` to paired set if absent.
  Future<void> addPaired(String host, int port) async {
    final id = idOfHostPort(host, port);
    final ids = await _loadIds();
    if (ids.contains(id)) return;
    await _saveIds([...ids, id]);
  }

  /// Sync check against a cached set (for ViewModel hot path).
  static bool isPairedSync(DiscoveredServer s, Set<String> cached) =>
      cached.contains(idOf(s));
}
