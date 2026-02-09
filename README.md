# DStyle

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://d3mz.github.io/DStyle.jl/dev/)
[![Build Status](https://github.com/D3MZ/DStyle.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/D3MZ/DStyle.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![DStyle](https://github.com/D3MZ/DStyle.jl/actions/workflows/dstyle.yml/badge.svg?branch=main)](https://github.com/D3MZ/DStyle.jl/actions/workflows/dstyle.yml)
[![Coverage](https://codecov.io/gh/D3MZ/DStyle.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/D3MZ/DStyle.jl)

Warning: This is Vibe Coded. Tests are updated everytime an edge case is found.
Tests codebases against my personal style of clean & fast code that both humans and machines can read easily. It tries to limit the vocabulary and the way things are done without hurting expressiveness.

# Usage

Install:
```julia
using Pkg
Pkg.add(url = "https://github.com/D3MZ/DStyle.jl")
```

Run checks (Aqua.jl-like):
```julia
using Test
using DStyle
using YourPackageName

@testset "DStyle" begin
    DStyle.test_all(YourPackageName)
end
```
(`YourPackageName` is your package module name.)
Per-check options follow Aqua style, e.g. `DStyle.test_all(YourPackageName; kernel_function_barriers=(max_lines_from_signature=2,), julia_index_from_length=true)` or disable with `kernel_function_barriers=false` / `julia_index_from_length=false`.
This repository also runs `DStyle.test_all(DStyle)` in `.github/workflows/dstyle.yml`.

## Repository layout

```text
src/
  DStyle.jl                     # module entrypoint + includes
  core/                         # shared scanner, runner, reporting, path/string utilities
  rules/                        # one file per lint rule
  integrations/                 # CI/GitHub workflow helpers

test/
  runtests.jl                   # test entrypoint
  core/                         # runner-level behavior tests
  rules/                        # per-rule tests
  integrations/                 # workflow/badge tests
```

Generate a local (runtime) README badge:
```julia
using DStyle

badge = DStyle.readme_badge(
    paths = ["src/YourPackageName.jl"],
    link = "https://github.com/you/YourPackageName/actions",
)
println(badge)
```

Setup GitHub Actions once (recommended):
```julia
using DStyle

# run from your repo root
setup = DStyle.setupgithub!()
println(setup.badge)
```

# Features (& TODO)
Note: Passing examples could still fail due to other checks. It's not a style guide, the code inconsistency is for clarity.
- [x] [Adds a cool badge to your README.md with status](#adds-a-cool-badge-to-your-readmemd-with-status)
- [x] [Separate kernel functions (aka, function barriers)](#separate-kernel-functions-aka-function-barriers) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/performance-tips/#kernel-functions)
- [x] [Indexing with indices obtained from `length`, `size` etc is discouraged (JuliaIndexFromLength)](#indexing-with-indices-obtained-from-length-size-etc-is-discouraged-juliaindexfromlength) - [via Julia Docs](https://docs.julialang.org/en/v1/base/arrays/#Base.eachindex)
- [ ] [Modules and type names use capitalization and camel case](#modules-and-type-names-use-capitalization-and-camel-case) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [ ] [Functions are lowercase and use squashed words when readable](#functions-are-lowercase-and-use-squashed-words-when-readable) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [ ] [Functions do not contain underscores](#functions-do-not-contain-underscores) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [ ] [Functions that return Bool use approved predicate prefixes](#functions-that-return-bool-use-approved-predicate-prefixes) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [ ] [No abbreviation in function names](#no-abbreviation-in-function-names) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [ ] [Functions mutating at least one argument end in `!`](#functions-mutating-at-least-one-argument-end-in-bang) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Append-!-to-names-of-functions-that-modify-their-arguments)
- [ ] [Field names do not repeat the type name](#field-names-do-not-repeat-the-type-name) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [ ] [Break functions into multiple definitions](#break-functions-into-multiple-definitions) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/performance-tips/#Break-functions-into-multiple-definitions)

# How it works

### Adds a cool badge to your README.md with status
How it works: `DStyle.readme_badge` runs style checks and produces a Shields.io badge snippet that reports pass/fail.
Implementation: Reuse `test_all(...; throw=false)` to count violations, then map status to badge color/message and return Markdown.

Pass
```julia
using DStyle

badge = DStyle.readme_badge(paths = ["src/YourPackageName.jl"], link = "https://github.com/you/YourPackageName/actions")
println(badge)
# [![DStyle status](https://img.shields.io/badge/DStyle-pass-brightgreen?style=flat-square)](...)
```

Fail
```julia
using DStyle

badge = DStyle.readme_badge(paths = ["src/NeedsRefactor.jl"])
println(badge)
# ![DStyle status](https://img.shields.io/badge/DStyle-fail%281%29-red?style=flat-square)
```

Dynamic CI badge (recommended):
```julia
using DStyle

setup = DStyle.setupgithub!()
println(setup.badge)
# [![DStyle](https://github.com/your-org/your-repo/actions/workflows/dstyle.yml/badge.svg)](...)
```

### Separate kernel functions (aka, function barriers)
How it works: Detect loops that are too close to dynamic setup code and require extracting loop bodies into a kernel helper function.
Implementation: For each function body, if a `for` or `while` loop appears immediately after setup lines and is not inside a helper call, raise a violation.

Pass
```julia
function filltwos!(a)
    for i = eachindex(a)
        a[i] = 2
    end
end

function strangetwos(n)
    a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
    filltwos!(a)
    return a
end
```

Fail
```julia
function strangetwos(n)
    a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
    for i = 1:n
        a[i] = 2
    end
    return a
end
```

### Indexing with indices obtained from length, size etc is discouraged (JuliaIndexFromLength)
How it works: Detect loops and indexing that derive bounds from `length` or `size`, which can break with non-1-based indexing.
Implementation: Flag patterns like `for i in 1:length(x)`, `for i in 1:size(A, 1)`, and `x[1:length(x)]`; suggest `eachindex` or `axes`.

Pass
```julia
function stableindexing(xs)
    for i in eachindex(xs)
        xs[i] += 1
    end
    return xs
end

function stabledims(A)
    for i in axes(A, 1)
        A[i, 1] = 0
    end
    return A
end
```

Fail
```julia
function unstableindexing(xs)
    for i in 1:length(xs)
        xs[i] += 1
    end
    return xs
end
```

### Modules and type names use capitalization and camel case
How it works: Enforce `UpperCamelCase` names for modules, structs, and abstract/concrete type definitions.
Implementation: Match `module`, `struct`, `mutable struct`, and `abstract type` declarations; reject names that do not start with uppercase or contain snake_case separators.

Pass
```julia
module SparseArraysExt

struct UnitRangeLike
    start::Int
    stop::Int
end

end
```

Fail
```julia
module sparse_arrays_ext

struct unit_range_like
    start::Int
    stop::Int
end

end
```

### Functions are lowercase and use squashed words when readable
How it works: Require function identifiers to start lowercase and avoid `CamelCase` in method names.
Implementation: Parse function declarations (`function foo`, `foo(args) = ...`) and flag names containing uppercase letters.

Pass
```julia
maximumvalue(xs) = maximum(xs)
haskeysafe(dict, key) = haskey(dict, key)
```

Fail
```julia
MaximumValue(xs) = maximum(xs)
hasKeySafe(dict, key) = haskey(dict, key)
```

### Functions do not contain underscores
How it works: Forbid underscore-separated function names.
Implementation: Scan function identifiers and fail when `_` exists in the base function name.

Pass
```julia
loadtable(path) = read(path, String)
```

Fail
```julia
load_table(path) = read(path, String)
```

### Functions that return Bool use approved predicate prefixes
How it works: Boolean-returning functions must start with approved prefixes (`is`, `has`, `can`, `should`).
Implementation: Infer Bool return from explicit `::Bool`, Boolean literals, or clear predicate expressions and validate the function name prefix.

Pass
```julia
isvalid(x)::Bool = x > 0
cantrade(balance)::Bool = balance > 0
```

Fail
```julia
valid(x)::Bool = x > 0
tradeable(balance)::Bool = balance > 0
```

### No abbreviation in function names
How it works: Catch compressed names that reduce readability (for example `indxin` instead of `indexin`).
Implementation: Maintain a denylist/heuristic for common abbreviations and report function names that match suspicious short forms.

Pass
```julia
indexinneedle(needle, haystack) = findfirst(==(needle), haystack)
```

Fail
```julia
indxin(needle, haystack) = findfirst(==(needle), haystack)
```

### Functions mutating at least one argument end in bang
How it works: Mutating methods must end with `!`.
Implementation: Detect assignment into argument-backed storage (`x[i] =`, `setfield!`, `push!` on argument) and enforce a trailing `!` in the function name.

Pass
```julia
function normalize!(xs)
    s = sum(xs)
    xs ./= s
    return xs
end
```

Fail
```julia
function normalize(xs)
    s = sum(xs)
    xs ./= s
    return xs
end
```

### Field names do not repeat the type name
How it works: Keep struct field names concise by avoiding repeated type tokens.
Implementation: Tokenize type name and field names, then fail when a field begins with or duplicates the type stem.

Pass
```julia
struct OrderBook
    bids
    asks
end
```

Fail
```julia
struct OrderBook
    orderbookbids
    orderbookasks
end
```

### Break functions into multiple definitions
How it works: Prefer dispatch-based method splits over broad branching on runtime types.
Implementation: Find functions with deep `if/elseif` trees that dispatch on `isa` or `typeof` checks and suggest split method definitions.

Pass
```julia
score(x::Int) = x + 1
score(x::AbstractFloat) = x + 0.5
```

Fail
```julia
function score(x)
    if x isa Int
        return x + 1
    elseif x isa AbstractFloat
        return x + 0.5
    end
    return x
end
```
