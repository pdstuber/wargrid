# Ported from GeneralsGameCode-macOS (fork of TheSuperHackers/GeneralsGameCode), revision eb595cfc9,
# Core/Libraries/Source/Compression/EAC/refdecode.cpp, REF_decode (decode only).
# Copyright 2025 Electronic Arts Inc., GPL-3.0-or-later with EA's additional terms:
# see game/data/maps/NOTICE.md.


def decode(data: bytes) -> bytes:
    kind = (data[0] << 8) | data[1]
    i = 2
    wide = 4 if kind & 0x8000 else 3
    if kind & 0x100:
        i += wide
    size = int.from_bytes(data[i:i + wide], "big")
    i += wide
    out = bytearray()

    def copy(distance: int, count: int) -> None:
        src = len(out) - 1 - distance
        for _ in range(count):
            out.append(out[src])
            src += 1

    while True:
        first = data[i]
        i += 1
        if not first & 0x80:
            second = data[i]
            i += 1
            run = first & 3
            out += data[i:i + run]
            i += run
            copy(((first & 0x60) << 3) + second, ((first & 0x1C) >> 2) + 3)
        elif not first & 0x40:
            second, third = data[i], data[i + 1]
            i += 2
            run = second >> 6
            out += data[i:i + run]
            i += run
            copy(((second & 0x3F) << 8) + third, (first & 0x3F) + 4)
        elif not first & 0x20:
            second, third, fourth = data[i], data[i + 1], data[i + 2]
            i += 3
            run = first & 3
            out += data[i:i + run]
            i += run
            copy((((first & 0x10) >> 4) << 16) + (second << 8) + third,
                 (((first & 0x0C) >> 2) << 8) + fourth + 5)
        else:
            run = ((first & 0x1F) << 2) + 4
            if run <= 112:
                out += data[i:i + run]
                i += run
                continue
            run = first & 3
            out += data[i:i + run]
            break
    if len(out) != size:
        raise ValueError(f"refpack size {len(out)} != header {size}")
    return bytes(out)
