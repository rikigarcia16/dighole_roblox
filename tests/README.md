# Tests

The gameplay logic that does not need the Roblox engine (configuration, world generation,
inventory, profile migration, persistence encoding, terrain voxel layout) is tested outside
Studio with a tiny Luau runner and a Roblox shim (`harness.lua`).

## Running

```bash
# one-time: build the runner (needs Rust; compiles the official Luau VM via the mlua crate)
cargo build --release --manifest-path tools/luaucheck/Cargo.toml
export PATH="$PWD/tools/luaucheck/target/release:$PATH"

luaucheck run tests/run.lua           # unit + integration tests
luaucheck run tests/balance_sim.lua   # economy / progression simulation
luaucheck run tests/static_checks.lua # remotes declared, sounds referenced exist
luaucheck run tests/bench_generation.lua # generation cost in the Luau VM
luaucheck check $(find src -name '*.lua')   # compile every script (syntax check)
```

Run them from the repository root.

### Without Rust: Lune

[Lune](https://github.com/lune-org/lune) (a single Luau executable) runs the same files through
`tools/lune/run.luau`, which provides the same globals as `luaucheck`:

```bash
lune run tools/lune/run.luau run tests/run.lua
lune run tools/lune/run.luau run tests/static_checks.lua
lune run tools/lune/run.luau check $(find src -name '*.lua')
```

Benchmarks (`bench_*.lua`) are slower under Lune because the scripts run with a custom
environment; use `luaucheck` for timing.

## What is NOT covered here

Anything that needs the engine: physics, collisions, replication, UI layout, DataStores,
ProximityPrompts, input. Those are covered by the manual Studio checklist in
`docs/PHASE1_REPORT.md`.
