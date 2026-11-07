# Wargrid logo design (small change)

Status: approved by the user 2026-11-07.

## Intent

Wargrid still shows Godot's robot wherever it appears: the WhatsApp preview of `wargrid.pdstuber.dev`, the browser tab, the macOS dock, the app icons. A shared link or an installed build should look like Wargrid (user, 2026-11-07).

- Goals: one Wargrid emblem in every place a person sees the game: web favicon and touch icons, link previews, the desktop window and dock icon, the macOS, Windows and Linux app icons, the startup splash, the README and GitHub's social preview.
- Non-goals: a wordmark or pixel font, in-game art, other screens.
- Anti-goals: blurry, smoothed pixel art; a Godot robot left anywhere a player sees it; anything resembling EA's faction emblems.

## Decisions (user, 2026-11-07)

- A pixel-art emblem that matches where the game is heading.
- Concept B "Grid crest", as shown in the mockup: a 32×32 shield in the game's palette, with navy field, light rim, the isometric desert grid tile, and blue and red chevrons for the two sides.
- Approach 1: a 32×32 master PNG is the source; a small Godot script derives the larger sizes with nearest-neighbour scaling, and every PNG is committed.
- Licence: the logo is GPL-3.0-or-later, like the code.

## Approaches considered

1. **Picked:** a master PNG plus `tools/logo_sizes.gd`. Pixel art naturally lives as a PNG, editable in any pixel editor; Godot is already the toolchain, and there are no new dependencies.
2. A text pixel map in a Python generator. Diffable, but awkward to edit and needs a hand-written PNG encoder.
3. PNGs committed once, without a script. Least code, but re-scaling by hand blurs the pixels by default.

## Design

- `game/art/logo-32.png`: the 32×32 master with transparency, written once from the approved mockup's pixel map.
- `tools/logo_sizes.gd` (headless, like `tools/godot_licenses.gd`) writes, all with nearest-neighbour scaling:
  - `game/icon.png`: 512×512, transparent.
  - `web/og.png`: 512×512 on the dark card colour.
  - `docs/images/social.png`: 1280×640 with the emblem centred on the card colour.
- `project.godot`:
  - `application/config/icon="res://icon.png"`.
  - The boot splash shows `res://icon.png` with `use_filter=false` on a dark `bg_color`.
- Shipping export presets (macOS, Windows Desktop, Web):
  - macOS and Windows set `application/icon_interpolation=0` (nearest), so the 1024 px icns and the ICO sizes stay crisp.
  - Windows Desktop sets `application/modify_resources=true`, so the `.exe` carries the icon. Godot 4.7.2's docs mention no external tool; the rehearsal export on the Linux runner proves it.
  - Web gets `html/head_include` with `og:title`, `og:description`, `og:image` (`https://wargrid.pdstuber.dev/og.png`), `og:url`, `og:type` and a matching `<meta name="description">`.
  - Linux and the favicon use the project icon, so they need no setting.
- `web/Dockerfile` copies `og.png` into the image next to the export.
- README: the emblem at the top, and the licence line "Code and the Wargrid logo: GPL-3.0-or-later; licence for other original art and audio: undecided".
- GitHub social preview: the user uploads `docs/images/social.png` in the repo settings. GitHub's API can't set it.

## Tests

- A headless test checks that `game/icon.png` equals the master scaled ×16 nearest-neighbour.
- The same test checks that `project.godot` points `config/icon` and the splash at it, and that the shipping presets set nearest interpolation, Windows resource modification and the `og:image` tag. Exported test packs skip the preset part, as MP5 already does.

## Calls left to the builder

- Exact card colour: the game's background grey.
- The og description wording, along the lines of "Isometric real-time strategy game. Play it in your browser."
- The README emblem size: 96 or 128 px, an even fraction of 512.

## Risks

- Windows `modify_resources` was off since the M5 presets with no recorded reason. If the Linux runner can't modify the exe, revert to `false` and record that the exe keeps Godot's icon.
- Link-preview caches: WhatsApp and others may show the old preview until their cache expires.
