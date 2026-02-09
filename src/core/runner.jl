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

function test_module_type_camel_case(
    paths::AbstractVector{<:AbstractString};
    broken::Bool = false,
    show_details::Bool = !broken,
)
    violations = RuleViolation[]
    foreach(paths) do path
        source = read(path, String)
        append!(violations, check_module_type_camel_case(source; file = path))
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

function test_module_type_camel_case(
    testtarget::Module;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    kwargs...,
)
    checkpaths = isnothing(paths) ? modulesourcepaths(testtarget) : collect(paths)
    return test_module_type_camel_case(checkpaths; kwargs...)
end

function test_function_name_lowercase(
    paths::AbstractVector{<:AbstractString};
    broken::Bool = false,
    show_details::Bool = !broken,
)
    violations = RuleViolation[]
    foreach(paths) do path
        source = read(path, String)
        append!(violations, check_function_name_lowercase(source; file = path))
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

function test_function_name_lowercase(
    testtarget::Module;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    kwargs...,
)
    checkpaths = isnothing(paths) ? modulesourcepaths(testtarget) : collect(paths)
    return test_function_name_lowercase(checkpaths; kwargs...)
end

function test_mutating_function_bang(
    paths::AbstractVector{<:AbstractString};
    broken::Bool = false,
    show_details::Bool = !broken,
)
    violations = RuleViolation[]
    foreach(paths) do path
        source = read(path, String)
        append!(violations, check_mutating_function_bang(source; file = path))
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

function test_mutating_function_bang(
    testtarget::Module;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    kwargs...,
)
    checkpaths = isnothing(paths) ? modulesourcepaths(testtarget) : collect(paths)
    return test_mutating_function_bang(checkpaths; kwargs...)
end

function test_field_name_type_repetition(
    paths::AbstractVector{<:AbstractString};
    broken::Bool = false,
    show_details::Bool = !broken,
)
    violations = RuleViolation[]
    foreach(paths) do path
        source = read(path, String)
        append!(violations, check_field_name_type_repetition(source; file = path))
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

function test_field_name_type_repetition(
    testtarget::Module;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    kwargs...,
)
    checkpaths = isnothing(paths) ? modulesourcepaths(testtarget) : collect(paths)
    return test_field_name_type_repetition(checkpaths; kwargs...)
end

"""
    test_all(; paths=nothing, max_lines_from_signature=1, throw=true)

Runs all currently implemented style checks over one or more Julia files.
"""
function test_all(;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    max_lines_from_signature::Int = 1,
    julia_index_from_length::Bool = true,
    module_type_camel_case::Bool = true,
    function_name_lowercase::Bool = true,
    mutating_function_bang::Bool = true,
    field_name_type_repetition::Bool = true,
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
        if module_type_camel_case
            append!(violations, check_module_type_camel_case(source; file = path))
        end
        if function_name_lowercase
            append!(violations, check_function_name_lowercase(source; file = path))
        end
        if mutating_function_bang
            append!(violations, check_mutating_function_bang(source; file = path))
        end
        if field_name_type_repetition
            append!(violations, check_field_name_type_repetition(source; file = path))
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
Use `rule=false` to disable a check, or pass a `NamedTuple` to configure
check kwargs.
"""
function test_all(
    testtarget::Module;
    kernel_function_barriers = true,
    julia_index_from_length = true,
    module_type_camel_case = true,
    function_name_lowercase = true,
    mutating_function_bang = true,
    field_name_type_repetition = true,
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
    if module_type_camel_case !== false
        @testset "Module/type camel case" begin
            test_module_type_camel_case(
                testtarget;
                paths = paths,
                ascheckkwargs(module_type_camel_case)...,
            )
        end
    end
    if function_name_lowercase !== false
        @testset "Function lowercase names" begin
            test_function_name_lowercase(
                testtarget;
                paths = paths,
                ascheckkwargs(function_name_lowercase)...,
            )
        end
    end
    if mutating_function_bang !== false
        @testset "Mutating functions end with !" begin
            test_mutating_function_bang(
                testtarget;
                paths = paths,
                ascheckkwargs(mutating_function_bang)...,
            )
        end
    end
    if field_name_type_repetition !== false
        @testset "Field/type repetition" begin
            test_field_name_type_repetition(
                testtarget;
                paths = paths,
                ascheckkwargs(field_name_type_repetition)...,
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
