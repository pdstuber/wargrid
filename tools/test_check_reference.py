import io
import json
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_reference as ref

INI = {
    "Data\\INI\\Object\\AmericaInfantry.ini": """Object AmericaInfantryRanger
  WeaponSet
    Weapon = PRIMARY RangerAdvancedCombatRifle
  End
  ArmorSet
    Armor           = HumanArmor
  End
  BuildCost = 225
  BuildTime = 5.0          ;in seconds
  Body = ActiveBody ModuleTag_03
    MaxHealth       = 180.0
  End
  Locomotor = SET_NORMAL BasicHumanLocomotor
End
""",
    "Data\\INI\\Weapon.ini": """Weapon RangerAdvancedCombatRifle
  PrimaryDamage = 5.0
  DamageType = SMALL_ARMS
  AttackRange = 100.0
  DelayBetweenShots = 100
  ClipSize = 3
  ClipReloadTime = 700
End
""",
    "Data\\INI\\Armor.ini": """Armor HumanArmor
  Armor = ARMOR_PIERCING 10%
End
Armor StructureArmor
  Armor = DEFAULT 100%
  Armor = SMALL_ARMS 50%
End
""",
    "Data\\INI\\Locomotor.ini": """Locomotor BasicHumanLocomotor
  Speed = 20  ; walking
  Acceleration = 100
End
""",
}


def big(files: dict) -> bytes:
    names = [name.encode("latin-1") + b"\0" for name in files]
    payloads = [text.encode("latin-1") for text in files.values()]
    index_size = sum(8 + len(name) for name in names)
    offset = 16 + index_size
    index = b""
    body = b""
    for name, payload in zip(names, payloads, strict=True):
        index += struct.pack(">II", offset + len(body), len(payload)) + name
        body += payload
    data = (
        b"BIGF"
        + struct.pack("<I", 16 + index_size + len(body))
        + struct.pack(">I", len(files))
        + struct.pack(">I", 16 + index_size)
        + index
        + body
    )
    return data


class ReferenceTests(unittest.TestCase):
    def test_reads_big_index(self):
        files = ref.read_big(big(INI))
        self.assertEqual(sorted(files), sorted(name.lower() for name in INI))
        self.assertIn("MaxHealth", files["data\\ini\\object\\americainfantry.ini"])

    def test_rejects_non_big(self):
        with self.assertRaises(ValueError):
            ref.read_big(b"NOPE" + bytes(12))

    def test_block_and_field(self):
        text = INI["Data\\INI\\Object\\AmericaInfantry.ini"]
        block = ref.block(text, "Object", "AmericaInfantryRanger")
        self.assertEqual(ref.field(block, "BuildTime"), "5.0")
        self.assertEqual(ref.field(block, "MaxHealth"), "180.0")
        self.assertIsNone(ref.block(text, "Object", "AmericaInfantry"))
        with self.assertRaises(KeyError):
            ref.field(block, "Missing")

    def test_armor_default_rules(self):
        armor = INI["Data\\INI\\Armor.ini"]
        self.assertEqual(ref.armor_percent(ref.block(armor, "Armor", "HumanArmor"), "ARMOR_PIERCING"), 10)
        self.assertEqual(ref.armor_percent(ref.block(armor, "Armor", "HumanArmor"), "SMALL_ARMS"), 100)
        self.assertEqual(ref.armor_percent(ref.block(armor, "Armor", "StructureArmor"), "ARMOR_PIERCING"), 100)
        self.assertEqual(ref.armor_percent(ref.block(armor, "Armor", "StructureArmor"), "SMALL_ARMS"), 50)

    def test_frame_conversion_rounds_up(self):
        self.assertEqual(ref.ms_to_ticks(100), 3)
        self.assertEqual(ref.ms_to_ticks(700), 21)
        self.assertEqual(ref.ms_to_ticks(101), 4)
        self.assertEqual(ref.ms_to_ticks(0), 0)

    def test_compare_marks_match_differ_and_departure(self):
        rows = ref.compare(
            [
                ("usa_rifle_infantry cost", 225, 225, None),
                ("usa_rifle_infantry speed", 0.8, 0.9, None),
                ("usa_light_vehicle speed", 2.4, 3.0, "legacy prototype unit"),
            ]
        )
        self.assertEqual([row[-1] for row in rows], ["match", "DIFFERS", "deliberate: legacy prototype unit"])

    def test_cli_reports_and_fails_on_difference(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "INIZH.big"
            archive.write_bytes(big(INI))
            wargrid = Path(directory) / "wargrid.json"
            values: dict[str, Any] = {
                "usa_rifle_infantry": {
                    "cost": 225,
                    "ticks": 150,
                    "max_hp": 180000,
                    "armor": "human",
                    "speed": 0.8,
                    "weapon": "rifle",
                },
                "weapons": {
                    "rifle": {
                        "damage": 5000,
                        "damage_type": "small_arms",
                        "range": 4.0,
                        "delay_ticks": 3,
                        "clip_size": 3,
                        "reload_ticks": 21,
                    }
                },
                "armor": {"human": {"small_arms": 100, "armor_piercing": 10}},
            }
            wargrid.write_text(json.dumps(values))
            out = io.StringIO()
            code = ref.main(
                [str(archive), "--wargrid-json", str(wargrid), "--skip-hash", "--only", "usa_rifle_infantry"], out
            )
            self.assertEqual(code, 0, out.getvalue())
            self.assertIn("usa_rifle_infantry speed", out.getvalue())
            values["usa_rifle_infantry"]["speed"] = 0.9
            wargrid.write_text(json.dumps(values))
            out = io.StringIO()
            self.assertEqual(
                ref.main(
                    [str(archive), "--wargrid-json", str(wargrid), "--skip-hash", "--only", "usa_rifle_infantry"], out
                ),
                1,
            )
            self.assertIn("DIFFERS", out.getvalue())

    def test_scout_car_weapon_is_compared(self):
        files = {
            "objects": """Object AmericaVehicleHumvee
  Weapon = PRIMARY HumveeGun
  Armor = HumveeArmor
  BuildCost = 700
  BuildTime = 10.0
  MaxHealth = 240.0
  Locomotor = SET_NORMAL HumveeLocomotor
End
""",
            "weapons": """Weapon HumveeGun
  PrimaryDamage = 10.0
  DamageType = COMANCHE_VULCAN
  AttackRange = 150.0
  DelayBetweenShots = 200
  ClipSize = 0
  ClipReloadTime = 0
End
""",
            "armor": "Armor HumveeArmor\n  Armor = SMALL_ARMS 50%\nEnd\n",
            "locomotor": "Locomotor HumveeLocomotor\n  Speed = 60\nEnd\n",
        }
        gun = {
            "damage": 10000,
            "damage_type": "rapid_fire",
            "range": 6.0,
            "delay_ticks": 6,
            "clip_size": 0,
            "reload_ticks": 0,
        }
        values: dict[str, Any] = {
            "usa_light_vehicle": {
                "cost": 700,
                "ticks": 300,
                "max_hp": 240000,
                "armor": "light_vehicle",
                "speed": 2.4,
                "weapon": "scout_gun",
            },
            "weapons": {"scout_gun": gun},
            "armor": {"light_vehicle": {"small_arms": 50, "armor_piercing": 100}},
        }
        results = ref.compare(ref.reference_rows(files, values, ["usa_light_vehicle"])[0])
        by_label = {row[0]: row[3] for row in results}
        self.assertEqual(by_label["usa_light_vehicle weapon"], "match")
        self.assertEqual(by_label["scout_gun damage_type"], "match")
        self.assertNotIn("DIFFERS", by_label.values())
        gun["damage"] = 5000
        results = ref.compare(ref.reference_rows(files, values, ["usa_light_vehicle"])[0])
        self.assertEqual({row[0]: row[3] for row in results}["scout_gun damage"], "DIFFERS")

    def test_hash_pin_rejects_other_data(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "INIZH.big"
            archive.write_bytes(big(INI))
            with self.assertRaises(ValueError):
                ref.load_archive(str(archive), check_hash=True)

    def test_reads_member_from_tarball(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "backup.tar.gz"
            data = big(INI)
            with tarfile.open(path, "w:gz") as tar:
                info = tarfile.TarInfo(ref.TAR_MEMBER)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
            self.assertIn("data\\ini\\weapon.ini", ref.load_archive(str(path), check_hash=False))

    def test_godot_failure_raises_with_stderr_tail(self):
        failed = subprocess.CompletedProcess([], 1, stdout="", stderr="SCRIPT ERROR: boom")
        with (
            mock.patch.object(ref.subprocess, "run", return_value=failed),
            self.assertRaisesRegex(RuntimeError, "boom"),
        ):
            ref.wargrid_definitions()

    def test_godot_call_has_a_timeout(self):
        ok = subprocess.CompletedProcess([], 0, stdout='WARGRID_DEFINITIONS {"a": 1}\n', stderr="")
        with mock.patch.object(ref.subprocess, "run", return_value=ok) as run:
            self.assertEqual(ref.wargrid_definitions(), {"a": 1})
        self.assertEqual(run.call_args.kwargs["timeout"], 300)


if __name__ == "__main__":
    unittest.main()
