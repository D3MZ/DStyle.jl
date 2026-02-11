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
Per-check options follow Aqua style, e.g. `DStyle.test_all(YourPackageName; kernel_function_barriers=(max_lines_from_signature=2,), julia_index_from_length=true, module_type_camel_case=true, function_name_lowercase=true, mutating_function_bang=true, field_name_type_repetition=true, simple_verb_redefinition=true)` or disable checks with `rule_name=false`.
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
- [x] [Adds a cool badge to your README.md with status](https://d3mz.github.io/DStyle.jl/dev/ci/)
- [x] [Adds DStyle under `[extras]` and `[targets].test`](#adds-dstyle-under-extras-and-targetstest)
- [x] [Separate kernel functions (aka, function barriers)](https://d3mz.github.io/DStyle.jl/dev/checks/) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/performance-tips/#kernel-functions)
- [x] [Indexing with indices obtained from `length`, `size` etc is discouraged (JuliaIndexFromLength)](https://d3mz.github.io/DStyle.jl/dev/checks/) - [via Julia Docs](https://docs.julialang.org/en/v1/base/arrays/#Base.eachindex)
- [x] [Modules and type names use capitalization and camel case](https://d3mz.github.io/DStyle.jl/dev/checks/) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [x] [Functions are lowercase and use squashed words when readable](https://d3mz.github.io/DStyle.jl/dev/checks/) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [x] [Constructor exemptions include macro structs and const type aliases](#constructor-exemptions-include-macro-structs-and-const-type-aliases)
- [x] [Do not add new verbs that are simple aliases of existing verbs](#do-not-add-new-verbs-that-are-simple-aliases-of-existing-verbs)
- [x] [Run checks on external codebases by path](#run-checks-on-external-codebases-by-path)
- [x] [Warn mode emits style findings without failing](#warn-mode-emits-style-findings-without-failing)
- [ ] Functions that return Bool use approved predicate prefixes - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [ ] No abbreviation in function names - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [x] [Functions mutating at least one argument end in `!`](https://d3mz.github.io/DStyle.jl/dev/checks/) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Append-!-to-names-of-functions-that-modify-their-arguments)
- [x] [Field names do not repeat the type name](https://d3mz.github.io/DStyle.jl/dev/checks/) - [via Julia Docs](https://docs.julialang.org/en/v1/manual/style-guide/#Use-naming-conventions-consistent-with-Julia-base/)
- [ ] Break functions into multiple definitions - [via Julia Docs](https://docs.julialang.org/en/v1/manual/performance-tips/#Break-functions-into-multiple-definitions)

# Documentation

The detailed rule examples and implementation notes now live in the docs site:

- [Getting Started](https://d3mz.github.io/DStyle.jl/dev/getting-started/)
- [Checks and Examples](https://d3mz.github.io/DStyle.jl/dev/checks/)
- [CI and Badge Integration](https://d3mz.github.io/DStyle.jl/dev/ci/)
- [API Reference](https://d3mz.github.io/DStyle.jl/dev/api/)

### Adds DStyle under extras and targets.test

Use `install_test_dependency!` when you want DStyle to be test-only in your package:

```julia
using DStyle

result = DStyle.install_test_dependency!(project_path = "Project.toml")
println(result.project_path)
println(result.added_to_extras)
println(result.added_to_test_target)
```

`setupgithub!()` runs this by default and returns the metadata in `setup.test_dependency`.

### Constructor exemptions include macro structs and const type aliases

`function_name_lowercase` and `mutating_function_bang` now treat these as constructor names:

```julia
@kwdef mutable struct GPAgent
    active::Bool = false
end

const Orders{T} = Vector{T}

GPAgent(x) = x
Orders(x) = x
```

These constructor names are exempt from lowercase and mutating-`!` name checks.

### Do not add new verbs that are simple aliases of existing verbs

The `simple_verb_redefinition` check flags short aliases that only rename an
existing verb while forwarding arguments unchanged.

Fail:

```julia
record!(history::History, s::State) = push!(history, s)
```

Prefer:

```julia
push!(history, s)
```

### Run checks on external codebases by path

Use `test_codebase` when you want to run DStyle against another repository
directory:

```julia
using DStyle

violations = test_codebase(
    "/path/to/another-project";
    throw = false,
)

println(length(violations))
```

### Warn mode emits style findings without failing

Use `warn=true` with `throw=false` to emit `@warn` messages and still get back
the violation vector:

```julia
using DStyle

violations = test_all(
    paths = ["src/MyPkg.jl"];
    warn = true,
    throw = false,
)
```
