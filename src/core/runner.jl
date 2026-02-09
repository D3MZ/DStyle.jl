"""
    test_kernel_function_barriers(paths; max_lines_from_signature=1, broken=false, show_details=!broken)

Test that no kernel-function-barrier violations exist in `paths`.
Returns collected violations.
"""
function test_kernel_function_barriers(
    paths::AbstractVector{<:AbstractString};
    max_lines_from_signature::Int = 1,
    broken::Bool = false,
    show_details::Bool = !broken,
)
    violations = RuleViolation[]
    foreach(paths) do path
        source = read(path, String)
        append!(
            violations,
            check_kernel_function_barriers(
                source;
                file = path,
                max_lines_from_signature = max_lines_from_signature,
            ),
        )
    end

    if !isempty(violations) && show_details
        println(stderr, formatviolationreport(violations))
    end

    if broken
        @test_broken isempty(violations)
    else
        @test isempty(violations)
    end
    return violations
end

function test_kernel_function_barriers(
    testtarget::Module;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    kwargs...,
)
    checkpaths = isnothing(paths) ? modulesourcepaths(testtarget) : collect(paths)
    return test_kernel_function_barriers(checkpaths; kwargs...)
end

"""
    test_index_from_length(paths; broken=false, show_details=!broken)

Test that code does not index or iterate with `length`/`size` derived indices.
Returns collected violations.
"""
function test_index_from_length(
    paths::AbstractVector{<:AbstractString};
    broken::Bool = false,
    show_details::Bool = !broken,
)
    violations = RuleViolation[]
    foreach(paths) do path
        source = read(path, String)
        append!(violations, check_index_from_length(source; file = path))
    end

    if !isempty(violations) && show_details
        println(stderr, formatviolationreport(violations))
    end

    if broken
        @test_broken isempty(violations)
    else
        @test isempty(violations)
    end
    return violations
end

function test_index_from_length(
    testtarget::Module;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    kwargs...,
)
    checkpaths = isnothing(paths) ? modulesourcepaths(testtarget) : collect(paths)
    return test_index_from_length(checkpaths; kwargs...)
end

"""
    test_all(; paths=nothing, max_lines_from_signature=1, julia_index_from_length=true, throw=true)

Runs all currently implemented style checks over one or more Julia files.
"""
function test_all(;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    max_lines_from_signature::Int = 1,
    julia_index_from_length::Bool = true,
    throw::Bool = true,
)
    checkpaths = isnothing(paths) ? defaultsourcepaths() : collect(paths)
    violations = RuleViolation[]

    foreach(checkpaths) do path
        source = read(path, String)
        append!(
            violations,
            check_kernel_function_barriers(
                source;
                file = path,
                max_lines_from_signature = max_lines_from_signature,
            ),
        )
        if julia_index_from_length
            append!(violations, check_index_from_length(source; file = path))
        end
    end

    if throw && !isempty(violations)
        details = join(string.(violations), '\n')
        error("DStyle found style violations:\n$details")
    end

    return violations
end

"""
    test_all(testtarget::Module; kernel_function_barriers=true, julia_index_from_length=true, paths=nothing)

Aqua-style entrypoint. Runs style tests for `testtarget` using `@testset`.
Use `kernel_function_barriers=false` to disable the check, or pass a
`NamedTuple` to configure check kwargs.
"""
function test_all(
    testtarget::Module;
    kernel_function_barriers = true,
    julia_index_from_length = true,
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
)
    if kernel_function_barriers !== false
        @testset "Kernel function barriers" begin
            test_kernel_function_barriers(
                testtarget;
                paths = paths,
                ascheckkwargs(kernel_function_barriers)...,
            )
        end
    end
    if julia_index_from_length !== false
        @testset "JuliaIndexFromLength" begin
            test_index_from_length(
                testtarget;
                paths = paths,
                ascheckkwargs(julia_index_from_length)...,
            )
        end
    end
    return nothing
end

"""
    readme_badge(; paths=nothing, max_lines_from_signature=1, label="DStyle", style="flat-square", link=nothing)

Builds a Shields.io badge snippet for README files using current DStyle check
results. The badge message is `pass` when no violations exist; otherwise it is
`fail(<count>)`.
"""
function readme_badge(;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    max_lines_from_signature::Int = 1,
    label::AbstractString = "DStyle",
    style::AbstractString = "flat-square",
    link::Union{Nothing, AbstractString} = nothing,
)
    violations = test_all(
        paths = paths,
        max_lines_from_signature = max_lines_from_signature,
        throw = false,
    )
    message = isempty(violations) ? "pass" : "fail($(length(violations)))"
    color = isempty(violations) ? "brightgreen" : "red"

    badgeurl =
        "https://img.shields.io/badge/$(shieldescape(label))-$(shieldescape(message))-$color?style=$(urlescape(style))"
    image = "![DStyle status]($badgeurl)"

    if isnothing(link)
        return image
    end
    return "[$image]($(String(link)))"
end

function ascheckkwargs(kwargs::NamedTuple)
    return kwargs
end

function ascheckkwargs(flag::Bool)
    if !flag
        throw(ArgumentError("expected `true` when enabling check kwargs"))
    end
    return NamedTuple()
end
