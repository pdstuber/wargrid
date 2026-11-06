"""Compare Wargrid's unit, building, weapon and armor values with Zero Hour's shipped INI data.

Local research tool: reads the user's retail archive in place and never copies it. Usage:
    python3 tools/check_reference.py "/path/Command & Conquer Generals - Zero Hour.tar.gz"
"""

import argparse
import hashlib
import json
import math
import os
import re
import struct
import subprocess
import sys
import tarfile
from pathlib import Path

TAR_MEMBER = "Command & Conquer Generals - Zero Hour/INIZH.big"
PINNED_SHA256 = "1a6d41a7a2cb31e67ad2f868aca9264ad069c275e0074f8a0d970a336071e9a0"
UNITS_PER_CELL = 25.0
TICKS_PER_SECOND = 30

OBJECTS = {
    "infantry": "AmericaInfantryRanger",
    "tank": "AmericaTankCrusader",
    "builder": "AmericaVehicleDozer",
    "vehicle": "AmericaVehicleHumvee",
    "collector": "AmericaVehicleChinook",
    "barracks": "AmericaBarracks",
    "reactor": "AmericaPowerPlant",
    "depot": "AmericaSupplyCenter",
    "factory": "AmericaWarFactory",
}
WEAPONS = {"rifle": "RangerAdvancedCombatRifle", "cannon": "CrusaderTankGun"}
ARMORS = {
    "HumanArmor": "human",
    "TankArmor": "tank",
    "DozerArmor": "dozer",
    "HumveeArmor": "humvee",
    "StructureArmor": "structure",
    "ChinookArmor": "chinook",
}
DAMAGE_TYPES = ["SMALL_ARMS", "ARMOR_PIERCING"]
DEPARTURES = {
    "vehicle speed": "legacy M1/M2 prototype unit keeps 3.0",
    "vehicle weapon": "legacy unit is unarmed; Humvee is not in the M4 roster",
}
NOT_MODELLED = {
    "Locomotor": ["SpeedDamaged", "Acceleration", "TurnRate"],
    "Weapon": ["PrimaryDamageRadius", "ScatterRadiusVsInfantry"],
}


def read_big(data: bytes) -> dict:
    if data[:4] != b"BIGF":
        raise ValueError("not a BIG archive")
    count = struct.unpack(">I", data[8:12])[0]
    position, files = 16, {}
    for _ in range(count):
        offset, size = struct.unpack(">II", data[position : position + 8])
        end = data.index(b"\0", position + 8)
        name = data[position + 8 : end].decode("latin-1").lower()
        position = end + 1
        if offset + size > len(data):
            raise ValueError("entry outside archive: " + name)
        files[name] = data[offset : offset + size].decode("latin-1")
    return files


def load_archive(path: str, check_hash: bool = True) -> dict:
    if path.endswith(".big"):
        data = Path(path).read_bytes()
    else:
        with tarfile.open(path, "r:gz") as tar:
            data = tar.extractfile(TAR_MEMBER).read()
    if check_hash and hashlib.sha256(data).hexdigest() != PINNED_SHA256:
        raise ValueError("INIZH.big hash differs from the pinned reference; see docs/reference/installation.md")
    return read_big(data)


def block(text: str, kind: str, name: str):
    start = re.search(r"^%s\s+%s\s*(;.*)?$" % (kind, re.escape(name)), text, re.M)
    if not start:
        return None
    end = re.search(r"^End\b", text[start.end() :], re.M)
    return text[start.start() : start.end() + end.start()]


def field(text: str, key: str) -> str:
    match = re.search(r"^\s*%s\s*=\s*([^;\r\n]+)" % key, text, re.M)
    if not match:
        raise KeyError(key)
    return match.group(1).strip()


def armor_percent(armor_block: str, damage_type: str) -> int:
    # Armor.cpp starts every coefficient at 100%; DEFAULT then the named type override it.
    entries = dict(
        (kind.upper(), int(float(value)))
        for kind, value in re.findall(r"^\s*Armor\s*=\s*(\w+)\s+([\d.]+)%", armor_block, re.M)
    )
    return entries.get(damage_type, entries.get("DEFAULT", 100))


def ms_to_ticks(milliseconds: float) -> int:
    return math.ceil(milliseconds * TICKS_PER_SECOND / 1000.0)


def compare(rows: list) -> list:
    out = []
    for label, reference, wargrid, departure in rows:
        same = (
            math.isclose(reference, wargrid, abs_tol=1e-9)
            if isinstance(reference, float) or isinstance(wargrid, float)
            else reference == wargrid
        )
        out.append(
            (label, reference, wargrid, "match" if same else ("deliberate: " + departure if departure else "DIFFERS"))
        )
    return out


def _find(files: dict, kind: str, name: str) -> str:
    for text in files.values():
        found = block(text, kind, name)
        if found:
            return found
    raise KeyError("%s %s not found" % (kind, name))


def reference_rows(files: dict, wargrid: dict, kinds: list) -> tuple:
    rows, notes, weapons, armors = [], [], [], []
    for kind in kinds:
        ours, obj = wargrid[kind], _find(files, "Object", OBJECTS[kind])
        armor = field(obj, "Armor")
        armors.append(armor)
        rows += [
            (kind + " cost", int(field(obj, "BuildCost")), ours["cost"]),
            (kind + " ticks", round(float(field(obj, "BuildTime")) * TICKS_PER_SECOND), ours["ticks"]),
            (kind + " max_hp", round(float(field(obj, "MaxHealth")) * 1000), ours["max_hp"]),
            (kind + " armor", ARMORS[armor], ours["armor"]),
        ]
        if "power" in ours:
            rows.append((kind + " power", int(field(obj, "EnergyProduction")), ours["power"]))
        if "speed" in ours:
            locomotor = _find(files, "Locomotor", field(obj, "Locomotor").split()[-1])
            rows.append((kind + " speed", float(field(locomotor, "Speed")) / UNITS_PER_CELL, ours["speed"]))
            notes += [
                "%s %s %s (not modelled)" % (kind, key, field(locomotor, key))
                for key in NOT_MODELLED["Locomotor"]
                if re.search(r"^\s*%s\s*=" % key, locomotor, re.M)
            ]
            primary = re.search(r"^\s*Weapon\s*=\s*PRIMARY\s+(\w+)", obj, re.M)
            reference_weapon = primary.group(1) if primary and primary.group(1) != "None" else ""
            ours_weapon = WEAPONS.get(ours.get("weapon", ""), "")
            rows.append((kind + " weapon", reference_weapon, ours_weapon))
            if ours_weapon:
                weapons.append(ours.get("weapon"))
    for name in dict.fromkeys(weapons):
        ours, weapon = wargrid["weapons"][name], _find(files, "Weapon", WEAPONS[name])
        rows += [
            (name + " damage", round(float(field(weapon, "PrimaryDamage")) * 1000), ours["damage"]),
            (name + " damage_type", field(weapon, "DamageType").lower(), ours["damage_type"]),
            (name + " range", float(field(weapon, "AttackRange")) / UNITS_PER_CELL, ours["range"]),
            (name + " delay_ticks", ms_to_ticks(float(field(weapon, "DelayBetweenShots"))), ours["delay_ticks"]),
            (name + " clip_size", int(field(weapon, "ClipSize")), ours["clip_size"]),
            (name + " reload_ticks", ms_to_ticks(float(field(weapon, "ClipReloadTime"))), ours["reload_ticks"]),
        ]
        notes += [
            "%s %s %s (not modelled)" % (name, key, field(weapon, key))
            for key in NOT_MODELLED["Weapon"]
            if re.search(r"^\s*%s\s*=" % key, weapon, re.M)
        ]
    for armor in dict.fromkeys(armors):
        armor_block = _find(files, "Armor", armor)
        for damage_type in DAMAGE_TYPES:
            rows.append(
                (
                    "%s vs %s" % (ARMORS[armor], damage_type.lower()),
                    armor_percent(armor_block, damage_type),
                    wargrid["armor"][ARMORS[armor]][damage_type.lower()],
                )
            )
    return [row + (DEPARTURES.get(row[0]),) for row in rows], notes


def wargrid_definitions() -> dict:
    game = Path(__file__).resolve().parent.parent / "game"
    command = [
        os.environ.get("GODOT_BIN", "godot"),
        "--headless",
        "--path",
        str(game),
        "--script",
        "res://scripts/debug/dump_definitions.gd",
    ]
    output = subprocess.run(command, capture_output=True, text=True, check=True).stdout
    for line in output.splitlines():
        if line.startswith("WARGRID_DEFINITIONS "):
            return json.loads(line[len("WARGRID_DEFINITIONS ") :])
    raise RuntimeError("Godot printed no WARGRID_DEFINITIONS line")


def main(argv: list, out=sys.stdout) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", help="Zero Hour backup .tar.gz or an extracted INIZH.big")
    parser.add_argument("--wargrid-json", help="definitions JSON instead of running Godot")
    parser.add_argument("--skip-hash", action="store_true", help="accept data other than the pinned INIZH.big")
    parser.add_argument("--only", nargs="*", default=list(OBJECTS), help="Wargrid kinds to check")
    args = parser.parse_args(argv)
    files = load_archive(args.archive, check_hash=not args.skip_hash)
    wargrid = json.loads(Path(args.wargrid_json).read_text()) if args.wargrid_json else wargrid_definitions()
    rows, notes = reference_rows(files, wargrid, args.only)
    results = compare(rows)
    print("REFERENCE %s sha256=%s" % (TAR_MEMBER, "skipped" if args.skip_hash else PINNED_SHA256), file=out)
    for label, reference, ours, status in results:
        print("%-28s reference=%-28s wargrid=%-28s %s" % (label, reference, ours, status), file=out)
    for note in notes:
        print("NOTE " + note, file=out)
    differing = sum(1 for row in results if row[3] == "DIFFERS")
    print(
        "REFERENCE CHECK %s %d rows, %d differ" % ("PASSED" if differing == 0 else "FAILED", len(results), differing),
        file=out,
    )
    return 0 if differing == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
