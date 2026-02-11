```@meta
CurrentModule = DStyle
```

# Getting Started

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/D3MZ/DStyle.jl")
```

## Run in tests (Aqua style)

```julia
using Test
using DStyle
using YourPackageName

@testset "DStyle" begin
    DStyle.test_all(YourPackageName)
end
```

## Configure rules

Disable any rule:

```julia
DStyle.test_all(
    YourPackageName;
    module_type_camel_case = false,
)
```

Pass per-rule options with a `NamedTuple`:

```julia
DStyle.test_all(
    YourPackageName;
    kernel_function_barriers = (max_lines_from_signature = 2,),
)
```

## Target specific files

```julia
DStyle.test_all(
    YourPackageName;
    paths = ["src/agents/MyAgent.jl", "src/core/State.jl"],
)
```

## Target an external repository path

```julia
violations = test_codebase(
    "/path/to/another-project";
    throw = false,
)
```

## Add DStyle as test-only dependency

If you want DStyle tracked in your package `Project.toml` under `[extras]` and
`[targets].test`:

```julia
using DStyle

DStyle.install_test_dependency!(project_path = "Project.toml")
```

## Collect violations without throwing

Use the non-module entrypoint for scripting and custom reporting:

```julia
violations = DStyle.test_all(
    paths = ["src/MyFile.jl"];
    throw = false,
)

for v in violations
    println(v)
end
```

## Emit warnings without failing

```julia
violations = DStyle.test_all(
    paths = ["src/MyFile.jl"];
    warn = true,
    throw = false,
)
```

## Rule-level checks

When you already have source text in memory, call checks directly:

```julia
source = read("src/MyFile.jl", String)
violations = DStyle.check_function_name_lowercase(source; file = "src/MyFile.jl")
```

Each check returns `Vector{RuleViolation}`.
