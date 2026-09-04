import 'dart:io';

import 'package:permission_handler/permission_handler.dart' as ph;

/// Result of a permission request.
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}

/// The two permissions the onboarding flow needs.
enum PermissionType {
  motionSensor,
  localNetwork,
}

/// A single permission request outcome.
class PermissionResult {
  const PermissionResult(this.type, this.status);

  final PermissionType type;
  final PermissionStatus status;

  bool get isGranted => status == PermissionStatus.granted;
}

/// Abstraction over the platform permission APIs so the flow can be tested
/// without triggering native dialogs.
abstract class PermissionService {
  Future<PermissionStatus> requestMotionSensor();
  Future<PermissionStatus> requestLocalNetwork();
}

/// Prompts for motion sensor and local network permissions, returning which
/// were granted. Denial surfaces as a non-fatal result — the caller decides
/// whether to warn.
class PermissionPrompts {
  PermissionPrompts({PermissionService? service})
      : _service = service ?? _PlatformPermissionService();

  final PermissionService _service;

  /// Requests motion sensor permission.
  Future<PermissionResult> requestMotionSensor() {
    return _request(PermissionType.motionSensor, _service.requestMotionSensor);
  }

  /// Requests local network permission.
  Future<PermissionResult> requestLocalNetwork() {
    return _request(PermissionType.localNetwork, _service.requestLocalNetwork);
  }

  Future<PermissionResult> _request(
    PermissionType type,
    Future<PermissionStatus> Function() call,
  ) async {
    return PermissionResult(type, await call());
  }

  /// Requests both permissions in order. Returns results in the same order.
  Future<List<PermissionResult>> requestAll() async {
    final results = <PermissionResult>[];
    results.add(await requestMotionSensor());
    results.add(await requestLocalNetwork());
    return results;
  }
}

/// Production [PermissionService] backed by `permission_handler`.
///
/// Motion sensor maps to [ph.Permission.sensors] (CoreMotion on iOS, body
/// sensors on Android). Local network maps to [ph.Permission.accessLocalNetwork]
/// on Android; on iOS it is implicit — triggered by mDNS discovery — so it
/// short-circuits to granted.
class _PlatformPermissionService implements PermissionService {
  @override
  Future<PermissionStatus> requestMotionSensor() async {
    final status = await ph.Permission.sensors.request();
    return _map(status);
  }

  @override
  Future<PermissionStatus> requestLocalNetwork() async {
    if (Platform.isIOS) {
      return PermissionStatus.granted;
    }
    final status = await ph.Permission.accessLocalNetwork.request();
    return _map(status);
  }

  PermissionStatus _map(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return PermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return PermissionStatus.permanentlyDenied;
    }
    return PermissionStatus.denied;
  }
}
