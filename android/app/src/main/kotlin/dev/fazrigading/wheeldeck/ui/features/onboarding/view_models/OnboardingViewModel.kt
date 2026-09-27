package dev.fazrigading.wheeldeck.ui.features.onboarding.view_models

import androidx.lifecycle.ViewModel
import dev.fazrigading.wheeldeck.data.repositories.OnboardingRepository
import dev.fazrigading.wheeldeck.data.services.PermissionPrompts
import dev.fazrigading.wheeldeck.data.services.PermissionType
import dev.fazrigading.wheeldeck.data.services.PermissionStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/// Presentation state for the first-run onboarding flow.
data class OnboardingUiState(
    /// True while the permission prompts are in flight; the buttons disable so a
    /// second tap cannot double-request.
    val requesting: Boolean = false,
    val motionSensorStatus: PermissionStatus? = null,
    val localNetworkStatus: PermissionStatus? = null,
)

/// First-run onboarding: requests the two permissions, records their outcomes,
/// and persists completion so the screen appears once.
///
/// Denial is not fatal — a denied sensor still drives the rotatable wheel, and a
/// denied network still reaches a manually-entered desktop — so the driver can
/// continue either way and grant later from the system settings.
class OnboardingViewModel(
    private val permissions: PermissionPrompts,
    private val onboardingRepository: OnboardingRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(OnboardingUiState())
    val uiState: StateFlow<OnboardingUiState> = _uiState.asStateFlow()

    /// Requests both permissions, records the outcomes, and persists completion.
    suspend fun requestAndComplete() {
        _uiState.update { it.copy(requesting = true) }
        try {
            permissions.requestAll().forEach { result ->
                when (result.type) {
                    PermissionType.MotionSensor ->
                        _uiState.update { it.copy(motionSensorStatus = result.status) }
                    PermissionType.LocalNetwork ->
                        _uiState.update { it.copy(localNetworkStatus = result.status) }
                }
            }
            onboardingRepository.setComplete()
        } finally {
            _uiState.update { it.copy(requesting = false) }
        }
    }

    /// Persists onboarding completion without requesting permissions.
    suspend fun complete() = onboardingRepository.setComplete()
}
