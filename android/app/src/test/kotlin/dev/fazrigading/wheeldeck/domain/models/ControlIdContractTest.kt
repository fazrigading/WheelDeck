package dev.fazrigading.wheeldeck.domain.models

import java.io.File
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/// The phone's ControlId wire values must match protocol/schema/controls.json.
class ControlIdContractTest {

    @Test
    fun `ControlId wire values match the protocol schema`() {
        val schema = WireJson.parseToJsonElement(findSchemaFile().readText()).jsonObject
        val controlId = schema["definitions"]!!
            .jsonObject["ControlId"]!!
            .jsonObject
        val expected = controlId["enum"]!!.jsonArray.map { it.jsonPrimitive.content }.toSet()

        val actual = ControlId.entries
            .map { WireJson.encodeToString(ControlId.serializer(), it).removeSurrounding("\"") }
            .toSet()

        assertEquals(expected, actual)
    }

    @Test
    fun `every ControlId has a documented wire value`() {
        for (control in ControlId.entries) {
            val wire = WireJson.encodeToString(ControlId.serializer(), control).removeSurrounding("\"")
            assertTrue("empty wire value for ${control.name}", wire.isNotEmpty())
        }
    }

    @Test
    fun `every schema wire value round-trips through ControlId`() {
        val schema = WireJson.parseToJsonElement(findSchemaFile().readText()).jsonObject
        val enumValues = schema["definitions"]!!
            .jsonObject["ControlId"]!!
            .jsonObject["enum"]!!
            .jsonArray
            .map { it.jsonPrimitive.content }

        for (name in enumValues) {
            val decoded = WireJson.decodeFromString<ControlId>("\"$name\"")
            assertEquals(name, WireJson.encodeToString(ControlId.serializer(), decoded).removeSurrounding("\""))
        }
    }

    /// Walks up from the module dir (android/app) to the repo root, like the Dart test.
    private fun findSchemaFile(): File {
        var dir = File(".").absoluteFile
        repeat(5) {
            val candidate = File(dir, "protocol/schema/controls.json")
            if (candidate.exists()) return candidate
            dir = dir.parentFile ?: return@repeat
        }
        error("Could not locate protocol/schema/controls.json from ${File(".").absolutePath}")
    }
}
