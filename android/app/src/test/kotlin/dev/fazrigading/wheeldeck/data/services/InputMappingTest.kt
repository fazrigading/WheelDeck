package dev.fazrigading.wheeldeck.data.services

import org.junit.Assert.assertEquals
import org.junit.Test

class InputMappingTest {

    @Test
    fun `defaults to gamepad`() {
        assertEquals(InputMapping.Gamepad, InputMapping.fromWireValue(null))
        assertEquals(InputMapping.Gamepad, InputMapping.fromWireValue("nonsense"))
    }

    @Test
    fun `parses both wire values`() {
        assertEquals(InputMapping.Keyboard, InputMapping.fromWireValue("keyboard"))
        assertEquals(InputMapping.Gamepad, InputMapping.fromWireValue("gamepad"))
    }
}
