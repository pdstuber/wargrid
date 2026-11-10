# Native sim spike: candidates and sources

Written 2026-11-10 (T4). Paper only: nothing here is measured. Labels: source (quoted, URL, fetch date), inferred (reasoned from sources or from the spike's own smoke build), unverified.

## Quotes (fetched live 2026-11-10 via WebFetch, which returns excerpts; the raw copies of the same day are in `~/projects/wargrid-native-work/prep/toolchain-sources/`)

- gdext book, web export, <https://godot-rust.github.io/book/toolchain/export-web.html>:
  - "We recommend version 3.1.74 when targeting Godot 4.3 or later."
  - "Web support in godot-rust is experimental and should be understood as such before proceeding."
  - "godot-rust cannot catch panics in Wasm yet due to limitations in the Rust compiler, so your game will abort."
  - "The reason why nightly `rustc` is required is the unstable flag to build `std`." Build: `cargo +nightly build -Zbuild-std --target wasm32-unknown-emscripten`.
  - Features `experimental-wasm` and, for single-threaded exports, `experimental-wasm-nothreads`.
- godot-cpp README, <https://github.com/godotengine/godot-cpp>: it does not mention web, Wasm or Emscripten. "You need the same C++ pre-requisites installed that are required for the `godot` repository." "GDExtensions targeting an earlier version of Godot should work in later minor versions, but not vice-versa." "Starting with version 10.x, godot-cpp is versioned independently from Godot."
- Godot, Exporting for the Web (latest), <https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html>: "If your project uses GDExtension, **Extension Support** needs to be enabled." "Note that GDExtensions still need to be specifically compiled for the web platform to work." "Enabling this feature requires the use of cross-origin isolation headers" (the spike's smoke build loaded a no-threads build without them; see the verification file, Sources).
- Godot, Compiling for the Web (latest; the page fetched is "latest", not a 4.7 snapshot, which is a gap), <https://docs.godotengine.org/en/latest/engine_details/development/compiling/compiling_for_web.html>: "The default export templates do not include GDExtension support for performance and compatibility reasons." "You can build the export templates using the option `dlink_enabled=yes` to enable GDExtension support". The same fetch gave the requirement "Emscripten 6.0.12+" for latest; the 4.7.2 template was built with 4.0.20 (measured in the verification file).
- gdext issue #438 "WebAssembly support" (open), <https://github.com/godot-rust/gdext/issues/438>: "Preliminary support has now been merged into master by #493." "For the time being, let's stay with emsdk 3." Pinned warning of 2026-06-09: "Be careful when updating to the latest Rust nightly as the `-Zemscripten-wasm-eh` option was removed"; workarounds are an older nightly or `-Cpanic=immediate-abort`, which "will crash the game on any error".
- gdext issue #1119 "RFC: Rust considering switching to using WebAssembly exception handling" (open), <https://github.com/godot-rust/gdext/issues/1119>: "exception handling needs to be disabled entirely on the latest nightly"; "It appears the working range of versions is quite narrow." (2026-07-15); 2026-10-02: "We got a PR coming in that fixes this issue on the Godot side", linking godotengine/godot#124118.

Not re-fetched: Godot PR 124118 itself (merged 2026-10-06 per the verification file; unverified here).

## Candidates

A: Godot, Rust gdext adapter, pure Rust core. B: Godot, C++ godot-cpp adapter, C ABI, the same Rust core. C: Godot, C++ adapter, C++ core. D: GDScript with native helpers for single hot functions. Baseline: today's GDScript.

| Axis | Baseline | A | B | C | D |
|---|---|---|---|---|---|
| Web toolchain maturity | Ships in the official template (inferred) | Experimental per the book (source); pinned old nightly, `-Zbuild-std`, Emscripten 3.1.74 recommended; a smoke build loaded in Firefox, Safari, Vivaldi (spike smoke, not a result) | godot-cpp README is silent on web (source); C++ web builds are the engine's own toolchain (inferred); the Rust core adds a second wasm module with its own link step (unverified) | Same as B minus Rust (inferred; unverified, not built) | Same as whichever language holds the helper |
| Float defaults | Godot `real_t` float32 in official builds; GDScript floats are double (source: engine headers, verification file) | Rust does not contract to FMA by default (inferred); a pure-Rust core can fix its own float type | Core as A; adapter converts types (inferred) | Compiler flags decide FMA contraction (clang `-ffp-contract` default differs by mode; unverified here) | Mixed: helper float32 vs GDScript double (inferred) |
| Safety | Memory safe | Safe Rust; panics abort on web (source) | Safe core, unsafe FFI seam (inferred) | No memory safety (inferred) | Depends on language |
| Build cost | None | Nightly pin, `-Zbuild-std`, emsdk pin, double import on first run (measured in the spike's smoke build) | Two toolchains plus a C ABI (inferred) | One toolchain family, SCons and emsdk (inferred) | Small, but still a template with extensions (inferred) |
| Hand-off shape | None | Packed arrays to a class method, results back (inferred; the spike measures it) | Same plus one more call layer (inferred) | Same as A (inferred) | Per-call cost paid at every hot function; no batching unless designed (inferred) |
| Migration cost | None | Rewrite slice logic in Rust, keep GDScript as reference (inferred) | Rust core and a C++ adapter (inferred) | Rewrite in C++; no shared core for non-Godot callers beyond C++ (inferred) | Lowest per function, but logic stays split across two languages (inferred) |

Rust and C++ are treated as equally fast for the same algorithm and layout until measured (handoff Stage 3). B, C and D are researched or unverified, never measured; only A is built.

Other languages (Zig and others): Zig has a wasm and Emscripten story and C interop, so it could sit behind the C ABI of B. Godot has no first-class adapter for it, so it would add a binding layer on top of a second toolchain. Not evaluated, nothing built.

## What CI and hosting would change for a native core (description only)

- Export templates: the stock web template has no extension support; the extension-enabled `web_dlink_nothreads_release` (installed 4.7.2, checked locally) must be used and a preset needs extension support on and thread support off. CI would install that template (source: the docs quote above; template choice measured locally).
- Toolchains: a pinned Rust nightly with `rust-src` and `wasm32-unknown-emscripten` (nightly has no clippy, so lint on stable), Emscripten 3.1.74 pinned in the build step, release libraries for every platform in the export (Mac, Linux, Windows, web). Cross-platform libraries mean a build matrix.
- Headers: the docs say extension support needs cross-origin isolation headers; the smoke build loaded without them (measured), but timers are coarser without them in Firefox (handoff). Hosting would serve the isolation headers as the benchmark server does today.
- Export size: the extension-enabled template splits the engine: `index.side.wasm` 44.1 MB plus `index.wasm` 1.5 MB, extension 362 kB (measured, smoke build). Compare with today's single-module export before deciding (not done in T4).
- First-import crash: the first editor-mode import with a new extension present crashes (exit 134), the second succeeds (measured). CI jobs that import a fresh checkout must import twice and require the second to pass.
- Engine upgrade: Godot PR 124118 (merged 2026-10-06, a later release, per the verification file; fix described in #1119 as "on the Godot side") changes the exception-handling mode of the extension-enabled main module, which will move the Rust nightly pin and the `rustflags`. Every Godot minor upgrade needs a re-run of the web smoke test; the gdext `api-4-7` feature and `godot = "=0.5.5"` pin move with it.
