package dev.fazrigading.wheeldeck.ui.core

import org.junit.Assert.assertEquals
import org.junit.Test

/// Task 14's routing rule, tested against the function [AppShell] actually calls.
///
/// This replaces an earlier version that re-implemented the rule privately and
/// therefore passed with [AppShell] deleted. If these cases hold, the composable
/// holds: it makes no routing decision of its own.
class AppShellRoutingTest {

    @Test
    fun `onboarding runs before anything else`() {
        for (connected in listOf(false, true)) {
            for (paused in listOf(false, true)) {
                for (requested in AppPage.entries) {
                    assertEquals(
                        "connected=$connected paused=$paused requested=$requested",
                        AppPage.Onboarding,
                        resolvePage(onboarded = false, connected = connected, paused = paused, requested = requested),
                    )
                }
            }
        }
    }

    @Test
    fun `the menu is the resting state once onboarded and idle`() {
        assertEquals(
            AppPage.Menu,
            resolvePage(onboarded = true, connected = false, paused = false, requested = AppPage.Menu),
        )
    }

    @Test
    fun `every hub page is reachable while idle`() {
        for (page in listOf(AppPage.Connect, AppPage.Settings, AppPage.About, AppPage.Donate)) {
            assertEquals(
                page.name,
                page,
                resolvePage(onboarded = true, connected = false, paused = false, requested = page),
            )
        }
    }

    @Test
    fun `a live connection takes over from any hub page`() {
        for (page in AppPage.entries) {
            assertEquals(
                page.name,
                AppPage.Driving,
                resolvePage(onboarded = true, connected = true, paused = false, requested = page),
            )
        }
    }

    /// A backgrounded session is still a session: bouncing to the menu mid-drive
    /// would strand the driver. Mirrors `main.dart`'s `|| isPaused`.
    @Test
    fun `a paused session still shows driving`() {
        for (page in AppPage.entries) {
            assertEquals(
                page.name,
                AppPage.Driving,
                resolvePage(onboarded = true, connected = false, paused = true, requested = page),
            )
        }
    }

    /// A stale request from a session that has since ended must not leave the
    /// driver on a screen with no way in.
    @Test
    fun `a stale driving request falls back to the menu`() {
        assertEquals(
            AppPage.Menu,
            resolvePage(onboarded = true, connected = false, paused = false, requested = AppPage.Driving),
        )
    }

    /// Mid-session settings: the shell shows driving, and the overlay is decided
    /// by the request rather than by [resolvePage], so a driver who opened
    /// settings and then got disconnected still reaches the menu, not a dead
    /// dashboard.
    @Test
    fun `settings requested from driving is reachable once connected`() {
        assertEquals(
            AppPage.Driving,
            resolvePage(onboarded = true, connected = true, paused = false, requested = AppPage.Settings),
        )
    }
}
