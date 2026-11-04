package wargrid.relay

import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.cio.CIO
import io.ktor.server.engine.embeddedServer
import io.ktor.server.response.respondText
import io.ktor.server.routing.get
import io.ktor.server.routing.routing
import io.ktor.server.websocket.WebSockets
import io.ktor.server.websocket.webSocket
import io.ktor.websocket.Frame
import io.ktor.websocket.close
import io.ktor.websocket.readText
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

data class RelayConfig(
    val port: Int = 8080,
    val protocol: Int = 1,
    val delay: Int = 4,
    val silenceMillis: Long = 10_000,
    val maxFrameBytes: Int = 65_536,
    val testDelayMillis: Long = 0,
)

// Single ordered queue per socket: a delayed tick frame never gets overtaken by a later `left`.
class Outbox {
    private class Item(val text: String, val dueMillis: Long)

    private val queue = Channel<Item>(Channel.UNLIMITED)
    private var lastDue = 0L

    @Synchronized
    fun sendDelayed(text: String, delayMillis: Long) {
        lastDue = maxOf(lastDue, System.currentTimeMillis() + delayMillis)
        queue.trySend(Item(text, lastDue))
    }

    fun send(text: String) = sendDelayed(text, 0)

    fun close() { queue.close() }

    suspend fun drain(write: suspend (String) -> Unit) {
        for (item in queue) {
            val wait = item.dueMillis - System.currentTimeMillis()
            if (wait > 0) delay(wait)
            write(item.text)
        }
    }
}

// Godot drops frames still queued when it sees the close, so the error must land before the close frame.
private const val CLOSE_GRACE_MILLIS = 200L

fun main() {
    val config = RelayConfig(
        port = System.getenv("PORT")?.toInt() ?: 8080,
        testDelayMillis = System.getenv("WARGRID_TEST_DELAY_MS")?.toLong() ?: 0, // shortcut: test-only knob, never set in fly.toml
    )
    embeddedServer(CIO, port = config.port) { relay(config) }.start(wait = true)
}

fun Application.relay(config: RelayConfig = RelayConfig(), codes: () -> String = ::randomCode) {
    install(WebSockets) { maxFrameSize = 1L shl 20 }
    val rooms = Rooms(config, codes)
    routing {
        get("/health") { call.respondText("ok") }
        webSocket("/ws") {
            val out = Outbox()
            val writer = launch { out.drain { send(Frame.Text(it)) }; close() }
            var joined: Join.Ok? = null
            try {
                while (true) {
                    val frame = withTimeoutOrNull(config.silenceMillis) { incoming.receiveCatching().getOrNull() } ?: break
                    val text = (frame as? Frame.Text)?.readText() ?: break
                    val message = parseEnvelope(text, config.maxFrameBytes)
                    val current = joined
                    if (message == null || (current == null) != (message.type == "hello")) return@webSocket reject(out, writer, "invalid message")
                    when (message.type) {
                        "hello" -> when (val result = rooms.join(message, out)) {
                            is Join.Ok -> joined = result
                            is Join.Refused -> return@webSocket reject(out, writer, result.reason)
                        }
                        "tick" -> if (!rooms.forward(current!!.room, current.seat, text, message)) return@webSocket reject(out, writer, "invalid message")
                        "ping" -> out.send("""{"type":"pong","t":${message.t}}""")
                        else -> return@webSocket reject(out, writer, "invalid message")
                    }
                }
            } finally {
                joined?.let { rooms.leave(it.code, it.room, it.seat) }
                out.close()
                writer.join()
            }
        }
    }
}

private suspend fun reject(out: Outbox, writer: kotlinx.coroutines.Job, reason: String) {
    out.send("""{"type":"error","reason":"$reason"}""")
    delay(CLOSE_GRACE_MILLIS)
    out.close()
    writer.join()
}
