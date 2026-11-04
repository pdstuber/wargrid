package wargrid.relay

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class VectorsTest {
    private val files = File("../protocol/vectors").listFiles { f -> f.extension == "json" }!!.sortedBy { it.name }

    @Test fun everyVectorParsesAsExpected() {
        assertTrue(files.size >= 12)
        for (file in files) {
            val vector = Json.parseToJsonElement(file.readText()) as JsonObject
            val text = vector["text"]!!.jsonPrimitive.content
            val parsed = parseEnvelope(text, 65_536)
            val valid = vector["valid"]?.jsonPrimitive?.boolean ?: true
            if (valid) {
                assertNotNull(parsed, file.name)
                assertEquals(vector["message"]!!.let { (it as JsonObject)["type"]!!.jsonPrimitive.content }, parsed.type, file.name)
            } else {
                assertNull(parsed, file.name)
            }
        }
    }
}
