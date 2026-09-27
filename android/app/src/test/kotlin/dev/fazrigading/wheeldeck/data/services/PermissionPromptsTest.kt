package dev.fazrigading.wheeldeck.data.services

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of mobile/test/data/services/permission_service_test.dart.
class PermissionPromptsTest {

    private class FakePermissionService(
        var motionSensorResult: PermissionStatus = PermissionStatus.Granted,
        var localNetworkResult: PermissionStatus = PermissionStatus.Granted,
    ) : PermissionService {
        var motionSensorCalls = 0
        var localNetworkCalls = 0

        override suspend fun requestMotionSensor(): PermissionStatus {
            motionSensorCalls++
            return motionSensorResult
        }

        override suspend fun requestLocalNetwork(): PermissionStatus {
            localNetworkCalls++
            return localNetworkResult
        }
    }

    @Test
    fun `requestMotionSensor returns granted when the service grants`() = runTest {
        val service = FakePermissionService()

        val result = PermissionPrompts(service).requestMotionSensor()

        assertEquals(PermissionType.MotionSensor, result.type)
        assertEquals(PermissionStatus.Granted, result.status)
        assertTrue(result.isGranted)
        assertEquals(1, service.motionSensorCalls)
    }

    @Test
    fun `requestMotionSensor returns denied when the service denies`() = runTest {
        val service = FakePermissionService(motionSensorResult = PermissionStatus.Denied)

        val result = PermissionPrompts(service).requestMotionSensor()

        assertEquals(PermissionStatus.Denied, result.status)
        assertFalse(result.isGranted)
    }

    @Test
    fun `requestMotionSensor returns permanentlyDenied`() = runTest {
        val service = FakePermissionService(motionSensorResult = PermissionStatus.PermanentlyDenied)

        val result = PermissionPrompts(service).requestMotionSensor()

        assertEquals(PermissionStatus.PermanentlyDenied, result.status)
        assertFalse(result.isGranted)
    }

    @Test
    fun `requestLocalNetwork returns granted when the service grants`() = runTest {
        val service = FakePermissionService()

        val result = PermissionPrompts(service).requestLocalNetwork()

        assertEquals(PermissionType.LocalNetwork, result.type)
        assertEquals(PermissionStatus.Granted, result.status)
        assertTrue(result.isGranted)
        assertEquals(1, service.localNetworkCalls)
    }

    @Test
    fun `requestLocalNetwork returns denied when the service denies`() = runTest {
        val service = FakePermissionService(localNetworkResult = PermissionStatus.Denied)

        val result = PermissionPrompts(service).requestLocalNetwork()

        assertEquals(PermissionStatus.Denied, result.status)
        assertFalse(result.isGranted)
    }

    @Test
    fun `requestLocalNetwork returns permanentlyDenied`() = runTest {
        val service = FakePermissionService(localNetworkResult = PermissionStatus.PermanentlyDenied)

        val result = PermissionPrompts(service).requestLocalNetwork()

        assertEquals(PermissionStatus.PermanentlyDenied, result.status)
        assertFalse(result.isGranted)
    }

    @Test
    fun `requestAll returns both results in order`() = runTest {
        val service = FakePermissionService(
            motionSensorResult = PermissionStatus.Granted,
            localNetworkResult = PermissionStatus.Denied,
        )

        val results = PermissionPrompts(service).requestAll()

        assertEquals(2, results.size)
        assertEquals(PermissionType.MotionSensor, results[0].type)
        assertTrue(results[0].isGranted)
        assertEquals(PermissionType.LocalNetwork, results[1].type)
        assertFalse(results[1].isGranted)
    }

    @Test
    fun `requestAll calls each service method once`() = runTest {
        val service = FakePermissionService()

        PermissionPrompts(service).requestAll()

        assertEquals(1, service.motionSensorCalls)
        assertEquals(1, service.localNetworkCalls)
    }

    /// Neither permission is a runtime permission on Android: the gyroscope
    /// needs no manifest grant, and local network access is gated by Wi-Fi, not
    /// by a dialog. The prompts still run, so the onboarding screen can report
    /// the outcome and a future platform can override [PermissionService].
    @Test
    fun `the Android service grants both without a dialog`() = runTest {
        val service: PermissionService = AndroidPermissionService

        assertEquals(PermissionStatus.Granted, service.requestMotionSensor())
        assertEquals(PermissionStatus.Granted, service.requestLocalNetwork())
    }
}
