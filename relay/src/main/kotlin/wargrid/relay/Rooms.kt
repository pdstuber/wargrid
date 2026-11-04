package wargrid.relay

import java.security.SecureRandom

const val CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

fun randomCode(): String {
    val random = SecureRandom()
    return String(CharArray(6) { CODE_ALPHABET[random.nextInt(CODE_ALPHABET.length)] })
}

class Seat(val number: Int, val out: Outbox) {
    var lastTick: Int? = null
    var frames = 0
    var bytes = 0L
}

class Room(val build: String) {
    val seats = mutableMapOf<Int, Seat>()
    var started = false
    val stats = mutableMapOf<Int, String>()
}

sealed interface Join {
    data class Ok(val seat: Seat, val code: String, val room: Room) : Join
    data class Refused(val reason: String) : Join
}

class Rooms(
    private val config: RelayConfig,
    private val codes: () -> String = ::randomCode,
    private val log: (String) -> Unit = ::println,
) {
    private val rooms = mutableMapOf<String, Room>()

    @Synchronized
    fun join(hello: Envelope, out: Outbox): Join {
        if (hello.protocol != config.protocol) return Join.Refused("protocol mismatch")
        val requested = hello.match!!
        val code: String
        val room: Room
        if (requested.isEmpty()) {
            code = generateSequence(codes) { codes() }.first { it !in rooms }
            room = Room(hello.build!!).also { rooms[code] = it }
        } else {
            code = requested
            room = rooms[code] ?: return Join.Refused("unknown match")
            if (room.build != hello.build) return Join.Refused("build mismatch")
            if (room.started || room.seats.size >= 2) return Join.Refused("match full")
        }
        val seat = Seat(room.seats.size + 1, out)
        room.seats[seat.number] = seat
        out.send(welcome(seat.number, code))
        if (room.seats.size == 2) {
            room.started = true
            room.seats.values.forEach { it.out.send("""{"type":"start","seats":[1,2],"delay":${config.delay}}""") }
        }
        return Join.Ok(seat, code, room)
    }

    @Synchronized
    fun forward(room: Room, seat: Seat, text: String, tick: Envelope): Boolean {
        val expected = (seat.lastTick ?: (config.delay - 1)) + 1
        if (!room.started || tick.seat != seat.number || tick.tick != expected) return false
        seat.lastTick = expected
        seat.frames++
        seat.bytes += text.toByteArray(Charsets.UTF_8).size
        room.seats.values.filter { it !== seat }.forEach { it.out.sendDelayed(text, config.testDelayMillis) }
        return true
    }

    @Synchronized
    fun leave(code: String, room: Room, seat: Seat) {
        if (room.seats[seat.number] !== seat) return
        room.seats.remove(seat.number)
        val after = seat.lastTick ?: (config.delay - 1)
        room.seats.values.forEach { it.out.send("""{"type":"left","seat":${seat.number},"after_tick":$after}""") }
        room.stats[seat.number] = "${seat.frames}f/${seat.bytes}B"
        if (room.seats.isEmpty()) {
            rooms.remove(code)
            log("MATCH END $code ${room.stats.entries.sortedBy { it.key }.joinToString(" ") { "seat${it.key}=${it.value}" }}")
        }
    }

    private fun welcome(seat: Int, code: String) = """{"type":"welcome","seat":$seat,"match":"$code"}"""
}
