# DStyle

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://D3MZ.github.io/DStyle.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://D3MZ.github.io/DStyle.jl/dev/)
[![Build Status](https://github.com/D3MZ/DStyle.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/D3MZ/DStyle.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/D3MZ/DStyle.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/D3MZ/DStyle.jl)

Tests against my personal style of clean code that both humans and machines can read easily.

Features
Note: Passing examples could still fail due to other checks. It's not a style guide, the code inconsistency is for clarity.
- [ ] Separate kernel functions (aka, function barriers) [Reference](https://docs.julialang.org/en/v1/manual/performance-tips/#kernel-functions)
For every function, check if the loop is <= 1 lines away from it.

Pass
```julia
function filltwos!(a)
    for i = eachindex(a)
        a[i] = 2
    end
end;

function strangetwos(n)
    a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
    filltwos!(a)
    return a
end;
```

Fail
```julia
function strangetwos(n)
           a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
           for i = 1:n
               a[i] = 2
           end
           return a
       end;
```

- [ ] Modules and type names use capitalization and camel case: module SparseArrays, struct UnitRange.
- [ ] Functions are lowercase (maximum, convert) and, when readable, with multiple words squashed together (isequal, haskey). 
- [ ] Functions do not contain underscores.
- [ ] Functions that return a Bool must be prefixed with is or has
- [ ] No abbreviation in function names (indexin rather than indxin)
- [ ] functions mutating at least one of their arguments end in !.
- [ ] Field names do not repeat the type name
- [ ] [Break functions into multiple definitions](https://docs.julialang.org/en/v1/manual/performance-tips/#Break-functions-into-multiple-definitions)

