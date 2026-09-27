package dev.fazrigading.wheeldeck.ui.features.onboarding.view_models

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.fazrigading.wheeldeck.data.repositories.OnboardingRepository
import dev.fazrigading.wheeldeck.data.services.InMemorySettingsStore
import dev.fazrigading.wheeldeck.data.services.PermissionPrompts
import dev.fazrigading.wheeldeck.data.services.PermissionService
import dev.fazrigading.wheeldeck.data.services.PermissionStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/// Port of the onboarding coverage in
/// mobile/lib/ui/features/onboarding/view_models/onboarding_view_model.dart.
/// The Dart suite has no test file for it, so this pins the two documented
/// promises: both permissions are requested and recorded, and completion is
/// persisted whether the driver continues or skips.
@OptIn(ExperimentalCoroutinesApi::class)
class OnboardingViewModelTest {

    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private class FakePermissionService(
        var motionSensor: PermissionStatus = PermissionStatus.Granted,
        var localNetwork: PermissionStatus = PermissionStatus.Granted,
    ) : PermissionService {
        var motionSensorCalls = 0
        var localNetworkCalls = 0

        override suspend fun requestMotionSensor(): PermissionStatus {
            motionSensorCalls++
            return motionSensor
        }

        override suspend fun requestLocalNetwork(): PermissionStatus {
            localNetworkCalls++
            return localNetwork
        }
    }

    private fun viewModel(service: PermissionService) = OnboardingViewModel(
        permissions = PermissionPrompts(service),
        onboardingRepository = OnboardingRepository(InMemorySettingsStore()),
    )

    @Test
    fun `a fresh view model has requested nothing`() = runTest(dispatcher) {
        val vm = viewModel(FakePermissionService())

        assertFalse(vm.uiState.value.requesting)
        assertNull(vm.uiState.value.motionSensorStatus)
        assertNull(vm.uiState.value.localNetworkStatus)
    }

    @Test
    fun `requesting records both outcomes`() = runTest(dispatcher) {
        val service = FakePermissionService(
            motionSensor = PermissionStatus.Granted,
            localNetwork = PermissionStatus.PermanentlyDenied,
        )
        val vm = viewModel(service)

        vm.requestAndComplete()
        advanceUntilIdle()

        assertEquals(PermissionStatus.Granted, vm.uiState.value.motionSensorStatus)
        assertEquals(PermissionStatus.PermanentlyDenied, vm.uiState.value.localNetworkStatus)
        assertFalse(vm.uiState.value.requesting)
        assertEquals(1, service.motionSensorCalls)
        assertEquals(1, service.localNetworkCalls)
    }

    @Test
    fun `requesting persists completion`() = runTest(dispatcher) {
        val store = InMemorySettingsStore()
        val repository = OnboardingRepository(store)
        val vm = OnboardingViewModel(PermissionPrompts(FakePermissionService()), repository)

        vm.requestAndComplete()
        advanceUntilIdle()

        assertTrue(repository.isComplete())
    }

    @Test
    fun `denial is not fatal`() = runTest(dispatcher) {
        val store = InMemorySettingsStore()
        val repository = OnboardingRepository(store)
        val vm = OnboardingViewModel(
            PermissionPrompts(
                FakePermissionService(
                    motionSensor = PermissionStatus.Denied,
                    localNetwork = PermissionStatus.Denied,
                ),
            ),
            repository,
        )

        vm.requestAndComplete()
        advanceUntilIdle()

        assertTrue(repository.isComplete())
        assertEquals(PermissionStatus.Denied, vm.uiState.value.motionSensorStatus)
    }

    @Test
    fun `skipping persists completion without requesting`() = runTest(dispatcher) {
        val service = FakePermissionService()
        val store = InMemorySettingsStore()
        val repository = OnboardingRepository(store)
        val vm = OnboardingViewModel(PermissionPrompts(service), repository)

        vm.complete()
        advanceUntilIdle()

        assertTrue(repository.isComplete())
        assertEquals(0, service.motionSensorCalls)
        assertEquals(0, service.localNetworkCalls)
        assertNull(vm.uiState.value.motionSensorStatus)
    }

    @Test
    fun `requesting clears its own spinner`() = runTest(dispatcher) {
        val vm = viewModel(FakePermissionService())

        vm.requestAndComplete()
        advanceUntilIdle()

        assertFalse(vm.uiState.value.requesting)
    }
}
