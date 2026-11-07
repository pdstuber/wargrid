# Local game-data reference

Inspected 2026-11-01. User supplied Steam Deck installation copies in:

- `~/CnC/Command and Conquer Generals.tar.gz`
- `~/CnC/Command & Conquer Generals - Zero Hour.tar.gz`

These are compressed installation backups, not unpacked directories. Read their tar members and selected BIG payloads in memory; no original installation files were changed and no game assets were copied into Wargrid.

Working copy (user approval, 2026-11-05): both tarballs extracted unchanged to `~/CnC/run/` (Zero Hour 2.7 GB, Generals 1.6 GB) so the [parity harness](zero-hour-parity-spike.md) can run the game; tarballs untouched. `tools/check_reference.py` on the extracted root `INIZH.big` matches the pinned hash below.

## Verified archive identities

Hashes identify the embedded BIG bytes, not the outer tarball. Entry counts include all indexed files/markers, not only gameplay INIs.

| Reference | Member inside tarball | Entries | SHA-256 |
|---|---|---:|---|
| Generals | `Command and Conquer Generals/INI.big` | 92 | `bff8d621088b25fd8b041c8acca020a020fabc66f972ab2bd131fc67d905a72c` |
| Zero Hour (root) | `Command & Conquer Generals - Zero Hour/INIZH.big` | 135 | `1a6d41a7a2cb31e67ad2f868aca9264ad069c275e0074f8a0d970a336071e9a0` |
| Zero Hour (nested, exclude) | `Command & Conquer Generals - Zero Hour/Data/INI/INIZH.big` | 99 | `d7bf5d8f8f20300c132e822ec10e95cdfb073ddb3554353d45711dead4c4285c` |
| Zero Hour patch | `Command & Conquer Generals - Zero Hour/PatchINI.big` | 1 | `16028d315c8c4d279beed15f1836a8998ff5c9a4d0d621d4a3d37213a0d9fe62` |

The Zero Hour backup also contains `ZH_Generals/INI.big`; its hash matches the standalone Generals `INI.big` above. Keep base-game and expansion definitions separate.

## Available research inputs

The root Zero Hour `INIZH.big` contains:

- `Data\INI\Object\AmericaVehicle.ini`, `AmericaInfantry.ini`, `AmericaAir.ini`, and `AmericaMiscUnit.ini` under the same object directory.
- `Data\INI\Weapon.ini`, `Armor.ini`, `Locomotor.ini`, `Upgrade.ini`, `Science.ini`, `CommandButton.ini`, and `CommandSet.ini`.
- `Data\INI\GameData.ini` and default definitions.

Selected payloads were read as text, including object definitions with cost, build time and health fields. This establishes that reference configuration is available; it does not establish fully resolved unit values after inheritance, overrides, upgrades and difficulty settings. Record archive hash, internal path and object/field for each value used in a research note.

## Duplicate and patch handling

**Do not use the nested `Data/INI/INIZH.big` as the Zero Hour baseline.** Its bytes differ from the root copy. At the inspected source revision, [GameEngine.cpp](https://github.com/electronicarts/CnC_Generals_Zero_Hour/blob/0a05454d8574207440a5fb15241b98ad0b435590/GeneralsMD/Code/GameEngine/Source/Common/GameEngine.cpp#L307) explicitly deletes that nested path during startup; the adjacent comment describes a duplicate shipped with some editions. Both backups remain untouched.

Selected patch indexes were inspected:

- Both games' `PatchINI.big`: one entry, `Data\INI\WindowTransitions.ini`.
- Zero Hour `PatchZH.big`: two Avenger model files and one zero-length `Data\*` marker; no INI entries.
- Generals `Patch.big`, also present under Zero Hour's `ZH_Generals/`: one UI mapped-image INI plus other entries.
- Both `PatchData.big` files: no INI entries.

The source reads BIG index counts/offsets in [Win32BIGFileSystem.cpp](https://github.com/electronicarts/CnC_Generals_Zero_Hour/blob/0a05454d8574207440a5fb15241b98ad0b435590/GeneralsMD/Code/GameEngineDevice/Source/Win32Device/Common/Win32BIGFileSystem.cpp#L85). All 11 selected archive indexes passed bounds checks. Zero-length markers can use offset zero and are not payloads. This was an inspection, not a complete implementation of the game's file-resolution or INI-loading rules.

## What this unblocks

Movement, economy and combat research can now combine engine source with shipped configuration instead of guessed stats. M0 still needs no retail data and must run in CI without access to these backups. Keep original data outside the project; research notes contain provenance and focused findings.

Unknowns: exact installed executable/build version, mod status, effective runtime overrides, and behavior under actual play. Treat this as a hash-pinned Steam Deck data snapshot, not a verified pristine Zero Hour 1.04 installation. Resolve version and loading precedence before claiming measured reference fidelity. Intended Wargrid fixes remain authoritative over original defects.
