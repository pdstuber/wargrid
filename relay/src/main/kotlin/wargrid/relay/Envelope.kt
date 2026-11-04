package wargrid.relay

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlin.math.abs
import kotlin.math.floor

data class Envelope(
    val type: String,
    val seat: Int? = null,
    val tick: Int? = null,
    val protocol: Int? = null,
    val build: String? = null,
    val match: String? = null,
    val t: String? = null,
)

private const val MAX_SAFE_INT = 9007199254740992.0
private val HASH = Regex("^[0-9a-f]{16}$")

private fun JsonObject.int(key: String): Int? {
    val p = this[key] as? JsonPrimitive ?: return null
    if (p.isString) return null
    val d = p.content.toDoubleOrNull() ?: return null
    if (abs(d) > MAX_SAFE_INT || d != floor(d) || abs(d) > Int.MAX_VALUE) return null
    return d.toInt()
}

private fun JsonObject.string(key: String): String? =
    (this[key] as? JsonPrimitive)?.takeIf { it.isString }?.content

private fun JsonObject.number(key: String): String? =
    (this[key] as? JsonPrimitive)?.takeIf { !it.isString && it.content.toDoubleOrNull() != null }?.content

private fun JsonObject.intList(key: String): Boolean {
    val list = this[key] as? JsonArray ?: return false
    return list.all { e: JsonElement ->
        val p = e as? JsonPrimitive
        p != null && !p.isString && p.content.toDoubleOrNull()?.let { it == floor(it) } == true
    }
}

private fun JsonObject.validHash(): Boolean {
    val hash = this["hash"] ?: return true
    val o = hash as? JsonObject ?: return false
    return o.int("tick") != null && o.string("value")?.matches(HASH) == true
}

fun parseEnvelope(text: String, maxBytes: Int): Envelope? {
    if (text.toByteArray(Charsets.UTF_8).size > maxBytes) return null
    val o = try { Json.parseToJsonElement(text) as? JsonObject } catch (_: Exception) { null } ?: return null
    return when (o.string("type")) {
        "hello" -> {
            val protocol = o.int("protocol")
            val build = o.string("build")
            val match = o.string("match")
            if (protocol == null || build == null || match == null) null
            else Envelope("hello", protocol = protocol, build = build, match = match)
        }
        "welcome" -> {
            val seat = o.int("seat")
            val match = o.string("match")
            if (seat == null || match == null) null else Envelope("welcome", seat = seat, match = match)
        }
        "start" -> if (o.intList("seats") && o.int("delay") != null) Envelope("start") else null
        "tick" -> {
            val seat = o.int("seat")
            val tick = o.int("tick")
            if (seat == null || tick == null || o["commands"] !is JsonArray || !o.validHash()) null
            else Envelope("tick", seat = seat, tick = tick)
        }
        "ping", "pong" -> o.number("t")?.let { Envelope(o.string("type")!!, t = it) }
        "left" -> if (o.int("seat") != null && o.int("after_tick") != null) Envelope("left", seat = o.int("seat")) else null
        "error" -> if (o.string("reason") != null) Envelope("error") else null
        else -> null
    }
}
