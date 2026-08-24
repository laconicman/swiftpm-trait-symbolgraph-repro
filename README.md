# Symbol-graph extraction ignores traits when downloading binary artifacts

A minimal, offline reproduction of a SwiftPM issue: **`swift package dump-symbol-graph`
downloads the binary artifact of a trait-gated dependency even when that trait is disabled.**
`swift build` and `swift package resolve` correctly do not.

Because `swift-docc-plugin` requests symbol graphs, this means **building documentation pulls
binary artifacts your build does not use and cannot link against**, with no way to opt out.

## Result on Swift 6.3.3

```
positive control — trait ENABLED, a download attempt is correct:
  swift build --traits Heavy                           ok

trait DISABLED — no download attempt should ever occur:
  swift build                                          ok
  swift package resolve                                ok
  swift package show-dependencies                      ok
  swift package dump-symbol-graph                      MISMATCH (expected download=no, got yes)
  swift package --disable-default-traits (dsg)         MISMATCH (expected download=no, got yes)
  plugin -> packageManager.getSymbolGraph              MISMATCH (expected download=no, got yes)
  plugin -> packageManager.build  (control)            ok

RESULT: present — a disabled trait's binary artifact was requested.
```

## Run it

```bash
./run.sh
```

- **Exit 0** — every expectation met; the bug is fixed on your toolchain.
- **Exit 1** — a disabled trait's artifact was requested; the bug is present.

**No network access is required or made.** The `binaryTarget` URL is `https://example.invalid/…`
and the checksum is zeroes, so nothing can be fetched — the download *attempt* is what the
harness detects. Runs are isolated with `--cache-path` / `--scratch-path`, so your real SwiftPM
cache is never touched.

## What is being tested

`App` declares a trait `Heavy` that is **not** a default trait, and takes its dependency on
`BinaryDep`'s product only `.when(traits: ["Heavy"])`. `BinaryDep` owns the `binaryTarget`.
With the trait disabled, `App` has no path to that artifact — `swift package show-dependencies`
correctly reports the graph as empty.

Two probes cover the plugin API as well as the CLI, because they are distinct call sites:

| Plugin | Calls | Behaviour |
|---|---|---|
| `probe-symbol-graph` | `packageManager.getSymbolGraph(for:options:)` | reproduces |
| `probe-build` | `packageManager.build(_:parameters:)` | **does not** — negative control |

That contrast localises the problem to symbol-graph extraction specifically, rather than to the
plugin API or to dependency resolution in general.

## Root cause

Both affected entry points pass `enableAllTraits: true` to
`SwiftCommandState.createBuildSystem(...)` when loading the package graph. Verified on `main`
(2026-08-23):

`Sources/Commands/PackageCommands/DumpCommands.swift:60-68` — `dump-symbol-graph`:

```swift
let buildSystem = try await swiftCommandState.createBuildSystem(
    // We are enabling all traits for dumping the symbol graph.
    enableAllTraits: true,
    cacheBuildManifest: false
)
```

`Sources/Commands/Utilities/PluginDelegate.swift:377-382` — `createSymbolGraphForPlugin`:

```swift
let buildSystem = try await swiftCommandState.createBuildSystem(
    explicitBuildSystem: buildSystem,
    enableAllTraits: true,
    cacheBuildManifest: false
)
```

That un-prunes the trait-gated dependency before binary artifacts are enumerated for download.
The target is pruned again later, at build-plan time — after the bytes have already moved.

Enabling all traits for symbol-graph extraction looks deliberate, and defensible: documentation
should presumably cover trait-gated public API. The artifact download appears to be an unintended
side effect of that choice, and there is no opt-out — because the value is hardcoded rather than
derived from user options, `--disable-default-traits` has no effect.

## Why it is worth fixing

Symbol-graph extraction only needs to parse and type-check sources; it never links, so a binary
artifact contributes nothing to its output. The cost is not theoretical — on a real package
using a 343 MiB artifact that unpacks to 1.33 GiB, and with SwiftPM keeping both the archive and
the extracted bundle, a documentation build consumed roughly **1.7 GB and 3.5 minutes** for a
trait that was never enabled. The same commands with `swift build` cost 44 KB and under a second.

## Layout

```
App/                     package with the disabled trait
  Plugins/ProbeSymbolGraph/   plugin API probe (reproduces)
  Plugins/ProbeBuild/         plugin API negative control
BinaryDep/               package owning the binaryTarget
run.sh                   regression harness
```

## Discussion

- Stack Overflow: <https://stackoverflow.com/questions/79997703/can-i-stop-swift-package-generate-documentation-from-downloading-a-trait-gated>

## Licence

MIT — see `LICENSE`.
