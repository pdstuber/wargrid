"""Dump Zero Hour's shipped INI blocks as JSONL with archive entry and line numbers.

Local research tool: reads the user's retail archive in place; the output stays under build/ and is never committed. Usage:
    python3 tools/zh_ini.py dump [archive] [--out PATH] [--skip-hash]
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import TextIO, TypedDict

from check_reference import load_archive

DEFAULT_ARCHIVE = Path(os.environ.get("HOME", "")) / "CnC/run/Command & Conquer Generals - Zero Hour/INIZH.big"
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "build/zh_ini/inizh.jsonl"

RADIUS_CURSORS = (
    "A10Strike",
    "Ambulance",
    "Ambush",
    "AnthraxBomb",
    "Artillery",
    "AttackContinueArea",
    "AttackDamageArea",
    "AttackScatterArea",
    "CarpetBomb",
    "ClearMines",
    "ClusterMines",
    "DaisyCutter",
    "EMPPulse",
    "EmergencyRepair",
    "Frenzy",
    "FriendlySpecialPower",
    "GuardArea",
    "HelixNapalmBomb",
    "NapalmStrike",
    "NuclearMissile",
    "OffensiveSpecialPower",
    "Paradrop",
    "ParticleCannon",
    "Radar",
    "ScudStorm",
    "SpectreGunship",
    "SpyDrone",
    "SpySatellite",
    "SuperweaponScatterArea",
)

# Retail INI has no opener syntax; Zero Hour's parser knows nested blocks per key.
OPENERS: frozenset[str] = frozenset(
    {
        "Draw",
        "Behavior",
        "Body",
        "ClientUpdate",
        "ArmorSet",
        "WeaponSet",
        "ConditionState",
        "DefaultConditionState",
        "TransitionState",
        "UnitSpecificSounds",
        "Prerequisites",
        "Turret",
        "AltTurret",
        "Nugget",
        "StaticGameLOD",
        "DynamicGameLOD",
        "ParticleSystem",
        "SideSounds",
        "Window",
        "Sound",
        "CreateObject",
        "CreateDebris",
        "DeliverPayload",
        "Mission",
        "LightPulse",
        "DeliveryDecal",
        "ImagePart",
        "AttackAreaDecal",
        "TargetingReticleDecal",
        "UnitSpecificFX",
        "GridDecalTemplate",
        "ViewShake",
        "TerrainScorch",
        "Tracer",
        "FXListAtBonePos",
        "ApplyRandomForce",
        "InheritableModule",
        "OverrideableByLikeKind",
        "Structure",
        "SideInfo",
        "SkillSet1",
        "SkillSet2",
        "SkirmishBuildList",
        "ParticlesAttachedToAnimatedBones",
        "FireWeapon",
        "Attack",
        *(f"{name}RadiusCursor" for name in RADIUS_CURSORS),
        *(f"GeneralPersona{i}" for i in range(12)),
    }
)
# Keys that open a block only without "=": "Turret = Turret01" is a plain field.
BARE_ONLY: frozenset[str] = frozenset({"Turret", "AltTurret", "ParticlesAttachedToAnimatedBones", "ParticleSystem"})


class Field(TypedDict):
    line: int
    key: str
    value: str
    path: list[str]


class Block(TypedDict):
    entry: str
    line: int
    end_line: int
    kind: str
    name: str | None
    args: list[str]
    fields: list[Field]


COMMENT = re.compile(r";|//")


def _split(text: str) -> tuple[str, str]:
    if "=" in text:
        key, value = text.split("=", 1)
        return key.strip(), value.strip()
    parts = text.split(None, 1)
    return parts[0], parts[1].strip() if len(parts) > 1 else ""


def parse_entry(entry: str, text: str) -> list[Block]:
    blocks: list[Block] = []
    current: Block | None = None
    stack: list[str] = []
    for number, raw in enumerate(text.splitlines(), 1):
        line = COMMENT.split(raw, 1)[0].strip()
        if not line:
            continue
        if current is None:
            key, value = _split(line)
            if "=" in line and key not in OPENERS:
                field: Field = {"line": number, "key": key, "value": value, "path": []}
                blocks.append(
                    {
                        "entry": entry,
                        "line": number,
                        "end_line": number,
                        "kind": key,
                        "name": None,
                        "args": [],
                        "fields": [field],
                    }
                )
            elif line.lower() == "end":
                raise ValueError(f"{entry}:{number}: End outside any block")
            else:
                tokens = line.replace("=", " ").split()
                current = {
                    "entry": entry,
                    "line": number,
                    "end_line": number,
                    "kind": tokens[0],
                    "name": tokens[1] if len(tokens) > 1 else None,
                    "args": tokens[2:],
                    "fields": [],
                }
            continue
        if line.lower() == "end":
            if stack:
                stack.pop()
            else:
                current["end_line"] = number
                blocks.append(current)
                current = None
            continue
        key, value = _split(line)
        if key in OPENERS and not (key in BARE_ONLY and "=" in line):
            stack.append(" ".join(line.split()))
        else:
            current["fields"].append({"line": number, "key": key, "value": value, "path": list(stack)})
    if current is not None:
        raise ValueError(f"{entry}:{current['line']}: block {current['kind']} has no End")
    return blocks


def dump(files: dict[str, str], out: Path) -> tuple[int, int, int]:
    entries = blocks = fields = 0
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as handle:
        for name in sorted(n for n in files if n.endswith(".ini")):
            entries += 1
            for block in parse_entry(name, files[name]):
                blocks += 1
                fields += len(block["fields"])
                handle.write(json.dumps(block, ensure_ascii=False) + "\n")
    return entries, blocks, fields


def main(argv: list[str], out: TextIO = sys.stdout) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["dump"])
    parser.add_argument("archive", nargs="?", default=str(DEFAULT_ARCHIVE))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--skip-hash", action="store_true")
    args = parser.parse_args(argv)
    target = Path(args.out)
    try:
        files = load_archive(args.archive, check_hash=not args.skip_hash)
        entries, blocks, fields = dump(files, target)
    except (OSError, ValueError) as error:
        target.unlink(missing_ok=True)
        print(f"zh_ini: {error}", file=sys.stderr)
        return 1
    print(f"ZH_INI entries={entries} blocks={blocks} fields={fields} out={target}", file=out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
