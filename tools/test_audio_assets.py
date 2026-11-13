# SPDX-License-Identifier: GPL-3.0-or-later
import struct
import unittest
from pathlib import Path

AUDIO = Path(__file__).resolve().parents[1] / "game" / "audio"
CREDITS = AUDIO / "CREDITS.md"
SFX = {
    "building_large",
    "building_small",
    "cannon",
    "carbine",
    "click",
    "error",
    "explosion",
    "infantry_death",
    "rifle_burst",
    "vehicle_death",
}
VOICE = {
    "base_under_attack",
    "building_lost",
    "construction_complete",
    "defeat",
    "insufficient_funds",
    "low_power",
    "unit_ready",
    "victory",
}
UNITS = {
    f"{role}_{line}_{n}"
    for role, names in {
        "infantry": ("move", "attack"),
        "vehicle": ("move", "attack"),
        "worker": ("move", "work"),
    }.items()
    for line in names
    for n in (1, 2)
}
MUSIC = {"conflict", "enemy_spotted", "hitman", "mammoth", "stay_the_course"}
BUDGET = 20_000_000


def audio_files() -> list[Path]:
    return sorted(
        p
        for p in AUDIO.rglob("*")
        if p.is_file() and p.suffix != ".import" and not p.name.startswith(".") and p != CREDITS
    )


def credit_rows() -> dict[str, list[str]]:
    if not CREDITS.exists():
        raise AssertionError("CREDITS.md missing")
    rows: dict[str, list[str]] = {}
    for line in CREDITS.read_text(encoding="utf-8").splitlines():
        cells = [c.strip().strip("`") for c in line.strip().strip("|").split("|")]
        if (
            line.startswith("|")
            and len(cells) == 8
            and cells[0] not in ("file", "")
            and not set(cells[0]) <= {"-", " "}
        ):
            if cells[0] in rows:
                raise AssertionError(f"duplicate credit row {cells[0]}")
            rows[cells[0]] = cells
    return rows


def wav_header(path: Path) -> tuple[int, int, int, int]:
    data = path.read_bytes()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise AssertionError(f"{path}: not RIFF/WAVE")
    pos = 12
    while pos + 8 <= len(data):
        cid, size = struct.unpack("<4sI", data[pos : pos + 8])
        if cid == b"fmt " and size >= 16:
            fmt, ch, rate, _, _, bits = struct.unpack("<HHIIHH", data[pos + 8 : pos + 24])
            return fmt, ch, bits, rate
        pos += 8 + size + (size & 1)
    raise AssertionError(f"{path}: no fmt chunk")


class AudioAssetsTest(unittest.TestCase):
    def test_layout(self) -> None:
        names = {
            d: {p.stem for p in (AUDIO / d).iterdir() if p.suffix != ".import" and not p.name.startswith(".")}
            for d in ("sfx", "voice", "music")
        }
        self.assertEqual(names["sfx"], SFX)
        self.assertEqual(names["voice"], VOICE | {"units"})
        self.assertEqual({p.stem for p in (AUDIO / "voice" / "units").iterdir() if p.suffix == ".wav"}, UNITS)
        self.assertEqual(names["music"], MUSIC)
        for p in audio_files():
            self.assertIn(p.relative_to(AUDIO).parts[0], ("sfx", "voice", "music"), str(p))
            self.assertIn(p.suffix, (".wav", ".ogg"), str(p))

    def test_every_file_credited(self) -> None:
        rows = credit_rows()
        expected = {str(p.relative_to(AUDIO)) for p in audio_files() if p.parts[-2] != "sfx"}
        self.assertEqual(set(rows), expected)

    def test_licences(self) -> None:
        for path, (_, title, source, author, licence, licence_url, _, _) in credit_rows().items():
            if path.startswith("music/"):
                self.assertIn(licence, ("CC-BY-3.0", "CC-BY-4.0"), path)
                self.assertTrue(title and title != "-", path)
                self.assertTrue(licence_url.startswith("https://"), path)
                self.assertTrue(author, path)
                self.assertTrue(source.startswith("https://"), path)
            else:
                self.assertEqual(licence, "GPL-3.0-or-later", path)
                voice = "bryce" if path.startswith("voice/units/") else "kristin"
                self.assertIn(f"en_US-{voice}-medium", source + " ".join(credit_rows()[path]), path)

    def test_music_attribution_text(self) -> None:
        text = CREDITS.read_text(encoding="utf-8")
        for title in ("Hitman", "Stay the Course"):
            self.assertIn(
                f"{title} Kevin MacLeod (incompetech.com)\n"
                "Licensed under Creative Commons: By Attribution 4.0\n"
                "https://creativecommons.org/licenses/by/4.0/",
                text,
            )

    def test_dotfiles_ignored(self) -> None:
        dot = AUDIO / "music" / ".DS_Store"
        dot.write_bytes(b"x")
        try:
            self.test_layout()
            self.test_every_file_credited()
        finally:
            dot.unlink()

    def test_size_budget(self) -> None:
        self.assertLessEqual(sum(p.stat().st_size for p in audio_files()), BUDGET)

    def test_wav_mono_16bit(self) -> None:
        for p in audio_files():
            if p.suffix == ".wav":
                self.assertEqual(wav_header(p), (1, 1, 16, 44100), str(p))

    def test_wargrid_audio_note(self) -> None:
        text = CREDITS.read_text(encoding="utf-8")
        self.assertIn("Wargrid-made audio is GPL-3.0-or-later", text)
        self.assertIn("tools/audio/synth.py", text)


if __name__ == "__main__":
    unittest.main()
