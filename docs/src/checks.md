```@meta
CurrentModule = DStyle
```

# Checks and Examples

This page documents each implemented check with practical pass/fail snippets.

## Kernel Function Barriers

Goal: keep dynamic setup separate from hot loops.

Pass:

```julia
function filltwos!(a)
    for i in eachindex(a)
        a[i] = 2
    end
end

function strangetwos(n)
    a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
    filltwos!(a)
    return a
end
```

Fail:

```julia
function strangetwos(n)
    a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
    for i in 1:n
        a[i] = 2
    end
    return a
end
```

Configuration:

```julia
DStyle.test_all(MyModule; kernel_function_barriers = (max_lines_from_signature = 2,))
```

## JuliaIndexFromLength

Goal: avoid `1:length(x)` and `1:size(x, d)` indexing patterns.

Pass:

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

Fail:

```julia
function unstableindexing(xs)
    for i in 1:length(xs)
        xs[i] += 1
    end
    return xs
end
```

## Module/Type Camel Case

Goal: modules and type names should be `UpperCamelCase`.

Pass:

```julia
module SparseArraysExt

struct UnitRangeLike
    start::Int
    stop::Int
end

end
```

Fail:

```julia
module sparse_arrays_ext

struct unit_range_like
    start::Int
    stop::Int
end

end
```

## Function Name Lowercase

Goal: method names are lowercase squashed words; constructors are exempt.

Pass:

```julia
maximumvalue(xs) = maximum(xs)
haskeysafe(dict, key) = haskey(dict, key)
```

Fail:

```julia
MaximumValue(xs) = maximum(xs)
hasKeySafe(dict, key) = haskey(dict, key)
```

Unicode note: signatures with Unicode argument names are supported, for example `runmean(lambda=1)=lambda` or `runmean(mu, x)`.

## Mutating Functions End With !

Goal: if a method mutates an input argument, it should end in `!`.

Pass:

```julia
function normalize!(xs)
    s = sum(xs)
    xs ./= s
    return xs
end
```

Fail:

```julia
function normalize(xs)
    s = sum(xs)
    xs ./= s
    return xs
end
```

Also flagged:

```julia
touch(xs) = (push!(xs, 1); xs)
```

## Field/Type Repetition

Goal: avoid repeating type names in field names and typed argument names.

Pass:

```julia
struct OrderBook
    bids
    asks
end

get(a::Agent, b::Broker, e::Environment) = (a, b, e)
```

Fail:

```julia
struct OrderBook
    orderbookbids
    orderbookasks
end

getstate(agent::Agent, broker::Broker, environment::Environment) = (agent, broker, environment)
```

Typical suggestion for the function above: `get(a::Agent, b::Broker, e::Environment)`.

## Simple Verb Redefinition

Goal: avoid introducing new verbs that are only aliases of existing ones.

Fail:

```julia
record!(history::History, s::State) = push!(history, s)
```

Pass:

```julia
record!(history::History, s::State) = push!(history, State(s))
```

## Planned Checks

These are listed in README as TODO and not currently enforced:

1. Bool-returning naming prefixes
2. No abbreviations in function names
3. Break functions into multiple definitions
