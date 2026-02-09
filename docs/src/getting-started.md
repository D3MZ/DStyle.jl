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

## Rule-level checks

When you already have source text in memory, call checks directly:

```julia
source = read("src/MyFile.jl", String)
violations = DStyle.check_function_name_lowercase(source; file = "src/MyFile.jl")
```

Each check returns `Vector{RuleViolation}`.
