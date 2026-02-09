```@meta
CurrentModule = DStyle
```

# DStyle

DStyle is a style checker for Julia packages with an Aqua-like testing entrypoint.

It focuses on a small set of opinionated rules around naming, indexing, and function structure, while staying easy to run in CI.

## What you get

- An opt-in test entrypoint: `DStyle.test_all(YourModule)`
- Per-rule toggles (disable a rule or pass config as a `NamedTuple`)
- CI helpers for workflow generation and dynamic status badges
- Rule-level functions when you need direct source checks

## Documentation map

- [Getting Started](getting-started.md): install, run, and configure checks
- [Checks and Examples](checks.md): pass/fail snippets and detection behavior
- [CI and Badge Integration](ci.md): workflow + README badge setup
- [API Reference](api.md): exported function reference

## Minimal usage

```julia
using Test
using DStyle
using YourPackageName

@testset "DStyle" begin
    DStyle.test_all(YourPackageName)
end
```

## Scope

Implemented checks today:

1. Kernel function barriers
2. JuliaIndexFromLength
3. Module/type camel case
4. Function name lowercase
5. Mutating function bang
6. Field/type repetition

Planned checks are tracked in the project README feature list.
