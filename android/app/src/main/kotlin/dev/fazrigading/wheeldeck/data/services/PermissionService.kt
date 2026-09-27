package dev.fazrigading.wheeldeck.data.services

/// Outcome of a permission request.
enum class PermissionStatus {
    Granted,
    Denied,

    /// The user blocked the prompt; only the system settings can undo it.
    PermanentlyDenied,
}

/// The permissions the onboarding flow reports on.
enum class PermissionType {
    MotionSensor,
    LocalNetwork,
}

/// A single permission request outcome.
data class PermissionResult(val type: PermissionType, val status: PermissionStatus) {
    val isGranted: Boolean get() = status == PermissionStatus.Granted
}

/// Abstraction over the platform permission APIs, so the onboarding flow can be
/// tested without native dialogs.
interface PermissionService {
    suspend fun requestMotionSensor(): PermissionStatus
    suspend fun requestLocalNetwork(): PermissionStatus
}

/// The Android [PermissionService]. Neither permission is a runtime permission
/// here, so both short-circuit to granted and no dialog ever appears:
///
/// - the gyroscope needs no manifest grant, only the `HIGH_SAMPLING_RATE_SENSORS`
///   feature, which is not a permission;
/// - local network access is gated by Wi-Fi state and the
///   `CHANGE_WIFI_MULTICAST_STATE` manifest entry, not by a runtime prompt.
///
/// The seam stays so the onboarding screen has a real outcome to render and a
/// platform with actual prompts only has to replace this one class.
object AndroidPermissionService : PermissionService {
    override suspend fun requestMotionSensor(): PermissionStatus = PermissionStatus.Granted
    override suspend fun requestLocalNetwork(): PermissionStatus = PermissionStatus.Granted
}

/// Prompts for the motion sensor and local network permissions, returning which
/// were granted. Denial surfaces as a non-fatal result — the caller decides
/// whether to warn.
class PermissionPrompts(private val service: PermissionService = AndroidPermissionService) {

    /// Requests the motion sensor permission.
    suspend fun requestMotionSensor() = request(PermissionType.MotionSensor) { service.requestMotionSensor() }

    /// Requests the local network permission.
    suspend fun requestLocalNetwork() = request(PermissionType.LocalNetwork) { service.requestLocalNetwork() }

    /// Requests both permissions in order. Returns results in the same order.
    suspend fun requestAll(): List<PermissionResult> =
        listOf(requestMotionSensor(), requestLocalNetwork())

    private suspend fun request(
        type: PermissionType,
        call: suspend () -> PermissionStatus,
    ) = PermissionResult(type, call())
}
