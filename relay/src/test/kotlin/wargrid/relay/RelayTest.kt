package wargrid.relay

import io.ktor.client.plugins.websocket.DefaultClientWebSocketSession
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.plugins.websocket.webSocket
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import io.ktor.websocket.Frame
import io.ktor.websocket.close
import io.ktor.websocket.readText
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private fun hello(match: String = "", build: String = "abc", protocol: Int = 1) =
    """{"type":"hello","protocol":$protocol,"build":"$build","match":"$match"}"""

private fun tick(seat: Int, tick: Int, pad: String = "") =
    """{"type":"tick","seat":$seat,"tick":$tick,"commands":[$pad]}"""

private suspend fun DefaultClientWebSocketSession.say(text: String) = send(Frame.Text(text))

private suspend fun DefaultClientWebSocketSession.hear(): String =
    withTimeout(3000) { (incoming.receive() as Frame.Text).readText() }

private fun code(welcome: String) = Regex(""""match":"([A-Z0-9]{6})"""").find(welcome)!!.groupValues[1]

private suspend fun ApplicationTestBuilder.twoSeats(
    build: String = "abc",
    body: suspend (DefaultClientWebSocketSession, DefaultClientWebSocketSession) -> Unit,
) {
    val client = createClient { install(WebSockets) }
    client.webSocket("/ws") {
        val a = this
        a.say(hello(build = build))
        val joinCode = code(a.hear())
        client.webSocket("/ws") {
            say(hello(joinCode, build))
            assertEquals("""{"type":"welcome","seat":2,"match":"$joinCode"}""", hear())
            assertEquals("""{"type":"start","seats":[1,2],"delay":4}""", hear())
            assertEquals("""{"type":"start","seats":[1,2],"delay":4}""", a.hear())
            body(a, this)
        }
    }
}

class RelayTest {
    @Test fun healthOk() = testApplication {
        application { relay() }
        assertEquals("ok", client.get("/health").bodyAsText())
    }

    @Test fun createJoinStart() = testApplication {
        application { relay() }
        twoSeats { _, _ -> }
    }

    @Test fun forwardsTickFramesByteForByte() = testApplication {
        application { relay() }
        twoSeats { a, b ->
            val frame = """{"type":"tick","seat":1,"tick":4,"commands":[{"target":[14.1,0.30000000000000004]}],"hash":{"tick":30,"value":"3a0ad3856b168044"}}"""
            a.say(frame)
            a.say(tick(1, 5))
            assertEquals(frame, b.hear())
            assertEquals(tick(1, 5), b.hear())
        }
    }

    @Test fun rejectsWrongSeatAndNonContiguousTick() = testApplication {
        application { relay() }
        twoSeats { a, b ->
            a.say(tick(2, 4))
            assertEquals("""{"type":"error","reason":"invalid message"}""", a.hear())
            assertEquals("""{"type":"left","seat":1,"after_tick":3}""", b.hear())
        }
        twoSeats { a, b ->
            a.say(tick(1, 4))
            a.say(tick(1, 6))
            assertEquals(tick(1, 4), b.hear())
            assertEquals("""{"type":"error","reason":"invalid message"}""", a.hear())
            assertEquals("""{"type":"left","seat":1,"after_tick":4}""", b.hear())
        }
    }

    @Test fun rejectsFirstTickBeforeDelay() = testApplication {
        application { relay() }
        twoSeats { a, b ->
            a.say(tick(1, 3))
            assertEquals("""{"type":"error","reason":"invalid message"}""", a.hear())
            assertEquals("""{"type":"left","seat":1,"after_tick":3}""", b.hear())
        }
    }

    @Test fun protocolAndBuildMismatch() = testApplication {
        application { relay() }
        val client = createClient { install(WebSockets) }
        client.webSocket("/ws") {
            say(hello(protocol = 2))
            assertEquals("""{"type":"error","reason":"protocol mismatch"}""", hear())
        }
        client.webSocket("/ws") {
            say(hello(build = "abc"))
            val joinCode = code(hear())
            client.webSocket("/ws") {
                say(hello(joinCode, "other"))
                assertEquals("""{"type":"error","reason":"build mismatch"}""", hear())
            }
            client.webSocket("/ws") {
                say(hello(joinCode, "abc"))
                assertTrue(hear().contains(""""seat":2"""))
            }
        }
    }

    @Test fun roomRejectsThirdSeatAndUnknownCode() = testApplication {
        application { relay() }
        twoSeats { a, b ->
            val third = createClient { install(WebSockets) }
            val matchCode = "ZZZZZZ"
            third.webSocket("/ws") {
                say(hello(matchCode))
                assertEquals("""{"type":"error","reason":"unknown match"}""", hear())
            }
            a.say(tick(1, 4))
            assertEquals(tick(1, 4), b.hear())
        }
    }

    @Test fun thirdSeatToRunningMatch() = testApplication {
        application { relay(RelayConfig(), codes = { "ABC234" }) }
        twoSeats { a, b ->
            val third = createClient { install(WebSockets) }
            third.webSocket("/ws") {
                say(hello("ABC234"))
                assertEquals("""{"type":"error","reason":"match full"}""", hear())
            }
            a.say(tick(1, 4))
            assertEquals(tick(1, 4), b.hear())
        }
    }

    @Test fun frameCapBoundary() = testApplication {
        application { relay() }
        val overhead = tick(1, 4, "\"\"").toByteArray().size
        twoSeats { a, b ->
            val exact = tick(1, 4, "\"" + "x".repeat(65_536 - overhead) + "\"")
            assertEquals(65_536, exact.toByteArray().size)
            a.say(exact)
            assertEquals(exact, b.hear())
            a.say(tick(1, 5, "\"" + "x".repeat(65_537 - overhead) + "\""))
            assertEquals("""{"type":"error","reason":"invalid message"}""", a.hear())
            assertEquals("""{"type":"left","seat":1,"after_tick":4}""", b.hear())
        }
    }

    @Test fun closeAnnouncesLeftWithLastTick() = testApplication {
        application { relay() }
        val client = createClient { install(WebSockets) }
        client.webSocket("/ws") {
            val b = this
            say(hello())
            val joinCode = code(hear())
            client.webSocket("/ws") {
                say(hello(joinCode))
                hear(); hear()
                say(tick(2, 4))
                say(tick(2, 5))
            }
            hear()
            assertEquals(tick(2, 4), hear())
            assertEquals(tick(2, 5), hear())
            assertEquals("""{"type":"left","seat":2,"after_tick":5}""", hear())
            b.say(ping(1))
            assertEquals("""{"type":"pong","t":1}""", hear())
        }
    }

    @Test fun silenceAnnouncesLeft() = testApplication {
        application { relay(RelayConfig(silenceMillis = 300)) }
        twoSeats { _, b ->
            repeat(6) {
                b.say(ping(it))
                delay(100)
            }
            val received = generateSequence { b.incoming.tryReceive().getOrNull() }.map { (it as Frame.Text).readText() }.toList()
            assertTrue(received.contains("""{"type":"left","seat":1,"after_tick":3}"""), received.toString())
        }
    }

    @Test fun pingPong() = testApplication {
        application { relay() }
        val client = createClient { install(WebSockets) }
        client.webSocket("/ws") {
            say(hello())
            hear()
            say(ping(123))
            assertEquals("""{"type":"pong","t":123}""", hear())
        }
    }

    @Test fun testDelayKeepsOrderAndHoldsLeftBehindTicks() = testApplication {
        application { relay(RelayConfig(testDelayMillis = 250)) }
        twoSeats { a, b ->
            val start = System.currentTimeMillis()
            a.say(tick(1, 4))
            a.say(tick(1, 5))
            assertEquals(tick(1, 4), b.hear())
            assertTrue(System.currentTimeMillis() - start >= 240)
            a.say(tick(1, 6))
            a.close()
            assertEquals(tick(1, 5), b.hear())
            assertEquals(tick(1, 6), b.hear())
            assertEquals("""{"type":"left","seat":1,"after_tick":6}""", b.hear())
        }
    }

    private fun ping(t: Int) = """{"type":"ping","t":$t}"""
}

class MatchStatsTest {
    @Test fun logsFramesAndBytesPerSeatWhenRoomEmpties() {
        val lines = mutableListOf<String>()
        val rooms = Rooms(RelayConfig(), { "ABCDEF" }, lines::add)
        val first = rooms.join(Envelope(type = "hello", protocol = 1, build = "b", match = ""), Outbox()) as Join.Ok
        val second = rooms.join(Envelope(type = "hello", protocol = 1, build = "b", match = "ABCDEF"), Outbox()) as Join.Ok
        val frame = tick(1, 4)
        assertTrue(rooms.forward(first.room, first.seat, frame, Envelope(type = "tick", seat = 1, tick = 4)))
        rooms.leave("ABCDEF", first.room, first.seat)
        assertTrue(lines.isEmpty())
        rooms.leave("ABCDEF", second.room, second.seat)
        assertEquals(listOf("MATCH END ABCDEF seat1=1f/${frame.length}B seat2=0f/0B"), lines)
    }
}
