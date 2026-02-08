module DStyle

using Test

export RuleViolation,
    check_index_from_length,
    check_kernel_function_barriers,
    check_redundant_int_quantity_names,
    github_actions_badge,
    github_actions_workflow,
    install_github_actions!,
    test_index_from_length,
    test_kernel_function_barriers,
    test_redundant_int_quantity_names,
    setupgithub!,
    setup!,
    setup_github_actions_badge!,
    readme_badge,
    test_all

struct RuleViolation
    rule::Symbol
    file::String
    function_name::String
    function_line::Int
    loop_line::Int
    message::String
    hint::String
end

Base.show(io::IO, violation::RuleViolation) = print(
    io,
    "$(violation.file):$(violation.loop_line): $(violation.rule): $(violation.message). Hint: $(violation.hint)",
)

"""
    check_kernel_function_barriers(source; file="<memory>", max_lines_from_signature=1)

Checks each `function ... end` block and reports a violation when the first loop
(`for`/`while`) appears more than `max_lines_from_signature` lines after the
function signature.
"""
function check_kernel_function_barriers(
    source::AbstractString;
    file::AbstractString = "<memory>",
    max_lines_from_signature::Int = 1,
)
    lines = split(source, '\n')
    violations = RuleViolation[]

    in_function = false
    function_name = ""
    function_line = 0
    first_loop_line = 0
    depth = 0

    for (line_number, raw_line) in pairs(lines)
        code_line = _strip_comment(raw_line)
        isempty(strip(code_line)) && continue

        if !in_function
            name = _function_name_from_definition(code_line)
            if !isnothing(name)
                in_function = true
                function_name = something(name)
                function_line = line_number
                first_loop_line = 0
                depth = _block_delta(code_line)
                continue
            end
        else
            if first_loop_line == 0 && _is_top_level_loop(code_line)
                first_loop_line = line_number
            end

            depth += _block_delta(code_line)
            if depth <= 0
                if first_loop_line > 0
                    distance = first_loop_line - function_line
                    if distance > max_lines_from_signature
                        message = "first loop starts $distance lines after function signature (max: $max_lines_from_signature)"
                        hint = "extract the loop into a kernel helper function and call it from $function_name"
                        push!(
                            violations,
                            RuleViolation(
                                :kernel_function_barrier,
                                String(file),
                                function_name,
                                function_line,
                                first_loop_line,
                                message,
                                hint,
                            ),
                        )
                    end
                end
                in_function = false
            end
        end
    end

    return violations
end

"""
    check_index_from_length(source; file="<memory>")

Reports lines that index or iterate using bounds derived from `length`/`size`,
for example `for i in 1:length(x)` or `x[1:size(x, 1)]`.
"""
function check_index_from_length(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    lines = split(source, '\n')
    violations = RuleViolation[]

    in_function = false
    function_name = "<top-level>"
    function_line = 0
    depth = 0
    in_multiline_string = false

    for (line_number, raw_line) in pairs(lines)
        code_input, in_multiline_string = _strip_docstring_line(raw_line, in_multiline_string)
        code_line = _strip_comment(code_input)
        code_line = _strip_string_literals(code_line)
        isempty(strip(code_line)) && continue

        if !in_function
            name = _function_name_from_definition(code_line)
            if !isnothing(name)
                in_function = true
                function_name = something(name)
                function_line = line_number
                depth = _block_delta(code_line)
                continue
            end
        end

        if _line_uses_index_from_length(code_line)
            message = "indexing with indices obtained from length/size is discouraged (JuliaIndexFromLength)"
            hint = "use eachindex(array) or axes(array, dim) instead of 1:length(array)/1:size(array, dim)"
            push!(
                violations,
                RuleViolation(
                    :julia_index_from_length,
                    String(file),
                    function_name,
                    function_line,
                    line_number,
                    message,
                    hint,
                ),
            )
        end

        if in_function
            depth += _block_delta(code_line)
            if depth <= 0
                in_function = false
                function_name = "<top-level>"
                function_line = 0
            end
        end
    end

    return violations
end

"""
    check_redundant_int_quantity_names(source; file="<memory>")

Reports `Int`-typed struct fields and function arguments whose names include
redundant quantity words (e.g. `count`, `size`, `num`) that the type already
communicates.
"""
function check_redundant_int_quantity_names(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    lines = split(source, '\n')
    violations = RuleViolation[]

    in_struct = false
    struct_name = ""
    struct_line = 0
    struct_depth = 0

    in_function_signature = false
    function_name = ""
    function_line = 0
    signature_lines = String[]

    for (line_number, raw_line) in pairs(lines)
        code_line = _strip_comment(raw_line)
        isempty(strip(code_line)) && continue

        if !in_struct
            struct_match = match(
                r"^\s*(?:(?:[A-Za-z_]\w*\.)?@[A-Za-z_]\w*\s+)*(?:mutable\s+)?struct\s+([A-Za-z_]\w*)",
                code_line,
            )
            if !isnothing(struct_match)
                in_struct = true
                struct_name = String(struct_match.captures[1])
                struct_line = line_number
                struct_depth = _block_delta(code_line)
                continue
            end
        else
            field_match = match(r"^\s*([A-Za-z_]\w*)\s*::\s*([A-Za-z_]\w*)", code_line)
            if !isnothing(field_match)
                field_name = String(field_match.captures[1])
                field_type = String(field_match.captures[2])
                if _is_integer_like_type(field_type) && _has_redundant_quantity_word(field_name)
                    message = "name '$field_name' redundantly encodes quantity for an integer-typed field"
                    hint = "prefer type-driven naming, e.g. '$(_compact_int_name(field_name))::$field_type'"
                    push!(
                        violations,
                        RuleViolation(
                            :redundant_int_quantity_name,
                            String(file),
                            struct_name,
                            struct_line,
                            line_number,
                            message,
                            hint,
                        ),
                    )
                end
            end

            struct_depth += _block_delta(code_line)
            if struct_depth <= 0
                in_struct = false
            end
            continue
        end

        if in_function_signature
            push!(signature_lines, code_line)
            if occursin(')', code_line)
                signature_text = join(signature_lines, " ")
                append!(
                    violations,
                    _function_signature_violations(
                        signature_text,
                        function_name,
                        function_line,
                        String(file),
                    ),
                )
                in_function_signature = false
                empty!(signature_lines)
            end
            continue
        end

        long_match = match(r"^\s*function\s+([A-Za-z_]\w*[!]?)\s*\(", code_line)
        if !isnothing(long_match)
            function_name = String(long_match.captures[1])
            function_line = line_number
            if occursin(')', code_line)
                append!(
                    violations,
                    _function_signature_violations(code_line, function_name, function_line, String(file)),
                )
            else
                in_function_signature = true
                push!(signature_lines, code_line)
            end
            continue
        end

        short_match = match(r"^\s*([A-Za-z_]\w*[!]?)\s*\([^)]*\)\s*=", code_line)
        if !isnothing(short_match)
            short_name = String(short_match.captures[1])
            append!(
                violations,
                _function_signature_violations(code_line, short_name, line_number, String(file)),
            )
        end
    end

    return violations
end

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
    for path in paths
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
        println(stderr, _format_violation_report(violations))
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
    check_paths = isnothing(paths) ? _module_source_paths(testtarget) : collect(paths)
    return test_kernel_function_barriers(check_paths; kwargs...)
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
    for path in paths
        source = read(path, String)
        append!(violations, check_index_from_length(source; file = path))
    end

    if !isempty(violations) && show_details
        println(stderr, _format_violation_report(violations))
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
    check_paths = isnothing(paths) ? _module_source_paths(testtarget) : collect(paths)
    return test_index_from_length(check_paths; kwargs...)
end

"""
    test_redundant_int_quantity_names(paths; broken=false, show_details=!broken)

Test that integer-typed fields and function arguments avoid redundant quantity
words in their names.
"""
function test_redundant_int_quantity_names(
    paths::AbstractVector{<:AbstractString};
    broken::Bool = false,
    show_details::Bool = !broken,
)
    violations = RuleViolation[]
    for path in paths
        source = read(path, String)
        append!(violations, check_redundant_int_quantity_names(source; file = path))
    end

    if !isempty(violations) && show_details
        println(stderr, _format_violation_report(violations))
    end

    if broken
        @test_broken isempty(violations)
    else
        @test isempty(violations)
    end
    return violations
end

function test_redundant_int_quantity_names(
    testtarget::Module;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    kwargs...,
)
    check_paths = isnothing(paths) ? _module_source_paths(testtarget) : collect(paths)
    return test_redundant_int_quantity_names(check_paths; kwargs...)
end

"""
    test_all(; paths=nothing, max_lines_from_signature=1, throw=true)

Runs all currently implemented style checks over one or more Julia files.
"""
function test_all(;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    max_lines_from_signature::Int = 1,
    julia_index_from_length::Bool = true,
    redundant_int_quantity_names::Bool = false,
    throw::Bool = true,
)
    check_paths = isnothing(paths) ? _default_source_paths() : collect(paths)
    violations = RuleViolation[]

    for path in check_paths
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
        if redundant_int_quantity_names
            append!(violations, check_redundant_int_quantity_names(source; file = path))
        end
    end

    if throw && !isempty(violations)
        details = join(string.(violations), '\n')
        error("DStyle found style violations:\n$details")
    end

    return violations
end

"""
    test_all(testtarget::Module; kernel_function_barriers=true, julia_index_from_length=true, redundant_int_quantity_names=true, paths=nothing)

Aqua-style entrypoint. Runs style tests for `testtarget` using `@testset`.
Use `kernel_function_barriers=false` to disable the check, or pass a
`NamedTuple` to configure check kwargs.
"""
function test_all(
    testtarget::Module;
    kernel_function_barriers = true,
    julia_index_from_length = true,
    redundant_int_quantity_names = false,
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
)
    if kernel_function_barriers !== false
        @testset "Kernel function barriers" begin
            test_kernel_function_barriers(
                testtarget;
                paths = paths,
                _askwargs(kernel_function_barriers)...,
            )
        end
    end
    if julia_index_from_length !== false
        @testset "JuliaIndexFromLength" begin
            test_index_from_length(
                testtarget;
                paths = paths,
                _askwargs(julia_index_from_length)...,
            )
        end
    end
    if redundant_int_quantity_names !== false
        @testset "Type-driven Int quantity names" begin
            test_redundant_int_quantity_names(
                testtarget;
                paths = paths,
                _askwargs(redundant_int_quantity_names)...,
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

    badge_url =
        "https://img.shields.io/badge/$(_shield_escape(label))-$(_shield_escape(message))-$color?style=$(_url_escape(style))"
    image = "![DStyle status]($badge_url)"

    if isnothing(link)
        return image
    end
    return "[$image]($(String(link)))"
end

"""
    github_actions_workflow(; name="DStyle", julia_version="1.11", paths=nothing, workflow_filename="dstyle.yml", package_url="https://github.com/D3MZ/DStyle.jl")

Returns a GitHub Actions workflow YAML string that runs `DStyle.test_all(...)`
on `push` and `pull_request`.
"""
function github_actions_workflow(;
    name::AbstractString = "DStyle",
    julia_version::AbstractString = "1.11",
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    workflow_filename::AbstractString = "dstyle.yml",
    package_url::AbstractString = "https://github.com/D3MZ/DStyle.jl",
)
    test_call = isnothing(paths) ? "DStyle.test_all(throw=true)" :
                "DStyle.test_all(paths=$( _julia_array_literal(paths) ); throw=true)"

    return """
name: $name
on:
  push:
  pull_request:

jobs:
  dstyle:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
        with:
          version: '$julia_version'
      - name: Run DStyle checks
        run: |
          julia -e '
            using Pkg
            Pkg.add(url="$( _quote_julia_string(package_url) )")
            using DStyle
            $test_call
          '
"""
end

"""
    install_github_actions!(; workflow_path=".github/workflows/dstyle.yml", kwargs...)

Installs a generated DStyle workflow file into your repository and returns the
written path.
"""
function install_github_actions!(;
    workflow_path::AbstractString = joinpath(".github", "workflows", "dstyle.yml"),
    kwargs...,
)
    mkpath(dirname(workflow_path))
    write(workflow_path, github_actions_workflow(; kwargs...))
    return String(workflow_path)
end

"""
    github_actions_badge(repo; workflow_filename="dstyle.yml", label="DStyle", branch=nothing)

Returns Markdown for a dynamic GitHub Actions badge for the provided repository
`owner/repo`.
"""
function github_actions_badge(
    repo::AbstractString;
    workflow_filename::AbstractString = "dstyle.yml",
    label::AbstractString = "DStyle",
    branch::Union{Nothing, AbstractString} = nothing,
)
    image_url = "https://github.com/$(String(repo))/actions/workflows/$(String(workflow_filename))/badge.svg"
    if !isnothing(branch)
        image_url *= "?branch=$(_url_escape(String(branch)))"
    end
    workflow_url = "https://github.com/$(String(repo))/actions/workflows/$(String(workflow_filename))"
    return "[![$(String(label))]($image_url)]($workflow_url)"
end

"""
    github_actions_badge(; repo=nothing, workflow_filename="dstyle.yml", label="DStyle", branch=nothing)

Like `github_actions_badge(repo; ...)`, but infers `repo` from
`ENV[\"GITHUB_REPOSITORY\"]` or your local `git remote origin` when omitted.
"""
function github_actions_badge(;
    repo::Union{Nothing, AbstractString} = nothing,
    workflow_filename::AbstractString = "dstyle.yml",
    label::AbstractString = "DStyle",
    branch::Union{Nothing, AbstractString} = nothing,
)
    detected_repo = isnothing(repo) ? _infer_github_repo() : String(repo)
    if isnothing(detected_repo)
        throw(ArgumentError("Could not infer GitHub repo. Pass repo=\"owner/repo\"."))
    end
    return github_actions_badge(
        something(detected_repo);
        workflow_filename = workflow_filename,
        label = label,
        branch = branch,
    )
end

"""
    setup_github_actions_badge!(; workflow_path=".github/workflows/dstyle.yml", repo=nothing, branch=nothing, kwargs...)

One-shot setup helper: writes the DStyle GitHub Actions workflow and returns
the dynamic badge markdown (with inferred repo unless explicitly provided).
Returns a named tuple `(workflow_path, repo, badge)`.
"""
function setup_github_actions_badge!(;
    workflow_path::AbstractString = joinpath(".github", "workflows", "dstyle.yml"),
    repo::Union{Nothing, AbstractString} = nothing,
    branch::Union{Nothing, AbstractString} = nothing,
    kwargs...,
)
    written = install_github_actions!(workflow_path = workflow_path; kwargs...)
    workflow_filename = basename(workflow_path)
    detected_repo = isnothing(repo) ? _infer_github_repo() : String(repo)
    if isnothing(detected_repo)
        throw(ArgumentError("Workflow installed, but repo could not be inferred. Pass repo=\"owner/repo\"."))
    end
    badge = github_actions_badge(
        something(detected_repo);
        workflow_filename = workflow_filename,
        branch = branch,
    )
    return (workflow_path = written, repo = something(detected_repo), badge = badge)
end

"""
    setupgithub!(; kwargs...)

One-call GitHub setup. Installs the DStyle GitHub Actions workflow and returns
`(workflow_path, repo, badge)` for immediate README usage.
"""
function setupgithub!(; kwargs...)
    return setup_github_actions_badge!(; kwargs...)
end

"""
    setup!(; kwargs...)

Backward-compatible alias for `setupgithub!()`.
"""
function setup!(; kwargs...)
    return setupgithub!(; kwargs...)
end

_askwargs(kwargs::NamedTuple) = kwargs
function _askwargs(flag::Bool)
    if !flag
        throw(ArgumentError("expected `true` when enabling check kwargs"))
    end
    return NamedTuple()
end

function _format_violation_report(violations::AbstractVector{RuleViolation})
    isempty(violations) && return "DStyle found 0 violations."

    grouped = Dict{String, Vector{RuleViolation}}()
    for violation in violations
        bucket = get!(grouped, violation.file, RuleViolation[])
        push!(bucket, violation)
    end

    files = sort!(collect(keys(grouped)))
    rule_name = _rule_display_name(violations[1].rule)
    header =
        "DStyle found $(length(violations)) $rule_name violation(s) across $(length(files)) file(s):"
    lines = String[header]

    for file in files
        push!(lines, _display_path(file))
        sort!(grouped[file], by = v -> (v.loop_line, v.function_name))
        for violation in grouped[file]
            push!(
                lines,
                "  L$(violation.loop_line) $(violation.function_name): $(violation.message)",
            )
        end
    end

    hints = unique(v.hint for v in violations)
    if length(hints) == 1
        push!(lines, "Hint: $(only(hints))")
    else
        push!(lines, "Hints:")
        for hint in hints
            push!(lines, "  - $hint")
        end
    end
    return join(lines, '\n')
end

function _rule_display_name(rule::Symbol)
    if rule == :kernel_function_barrier
        return "kernel function barrier"
    elseif rule == :julia_index_from_length
        return "JuliaIndexFromLength"
    elseif rule == :redundant_int_quantity_name
        return "redundant Int quantity name"
    else
        return String(rule)
    end
end

function _display_path(path::AbstractString)
    try
        relative = relpath(path, pwd())
        return startswith(relative, "..") ? String(path) : relative
    catch
        return String(path)
    end
end

function _default_source_paths()
    source_dir = joinpath(pwd(), "src")
    if !isdir(source_dir)
        return String[]
    end

    files = String[]
    for (root, _, names) in walkdir(source_dir)
        for name in names
            endswith(name, ".jl") || continue
            push!(files, joinpath(root, name))
        end
    end
    return sort!(files)
end

function _module_source_paths(pkg::Module)
    module_entry = pathof(pkg)
    if isnothing(module_entry)
        throw(ArgumentError("Could not resolve source path for module $(nameof(pkg)). Pass paths=[...] explicitly."))
    end

    src_dir = dirname(String(module_entry))
    if !isdir(src_dir)
        throw(ArgumentError("Resolved src directory does not exist: $src_dir"))
    end

    files = String[]
    for (root, _, names) in walkdir(src_dir)
        for name in names
            endswith(name, ".jl") || continue
            push!(files, joinpath(root, name))
        end
    end
    return sort!(files)
end

function _infer_github_repo()
    from_env = get(ENV, "GITHUB_REPOSITORY", "")
    if occursin(r"^[^/]+/[^/]+$", from_env)
        return from_env
    end

    from_git = _readchomp_or_nothing(`git config --get remote.origin.url`)
    isnothing(from_git) && return nothing
    return _repo_from_remote_url(from_git)
end

function _repo_from_remote_url(url::AbstractString)
    text = strip(String(url))
    for pattern in (
        r"^git@github\.com:([^/]+/[^/]+?)(?:\.git)?$",
        r"^https?://github\.com/([^/]+/[^/]+?)(?:\.git)?$",
        r"^ssh://git@github\.com/([^/]+/[^/]+?)(?:\.git)?$",
    )
        match_obj = match(pattern, text)
        if !isnothing(match_obj)
            return String(match_obj.captures[1])
        end
    end
    return nothing
end

function _readchomp_or_nothing(cmd::Cmd)
    try
        text = readchomp(cmd)
        return isempty(strip(text)) ? nothing : text
    catch
        return nothing
    end
end

function _julia_array_literal(paths::AbstractVector{<:AbstractString})
    escaped = ["\"$(_quote_julia_string(path))\"" for path in paths]
    return "[" * join(escaped, ", ") * "]"
end

function _quote_julia_string(value::AbstractString)
    text = String(value)
    text = replace(text, "\\" => "\\\\")
    text = replace(text, "\"" => "\\\"")
    return text
end

function _shield_escape(value::AbstractString)
    # Shields path segments use `-` as a separator; literal dashes are escaped as `--`.
    escaped = replace(String(value), "-" => "--", "_" => "__")
    return _url_escape(escaped)
end

function _url_escape(value::AbstractString)
    encoded = String(value)
    encoded = replace(encoded, "%" => "%25")
    encoded = replace(encoded, " " => "%20")
    encoded = replace(encoded, "(" => "%28", ")" => "%29")
    return encoded
end

function _strip_docstring_line(line::AbstractString, in_multiline_string::Bool)
    text = String(line)
    idx = findfirst("\"\"\"", text)

    if in_multiline_string
        if isnothing(idx)
            return "", true
        end
        stop = last(idx)
        rest = stop < lastindex(text) ? text[(stop + 1):end] : ""
        return _strip_docstring_line(rest, false)
    end

    if isnothing(idx)
        return text, false
    end

    start = first(idx)
    stop = last(idx)
    prefix = start > firstindex(text) ? text[firstindex(text):(start - 1)] : ""
    tail = stop < lastindex(text) ? text[(stop + 1):end] : ""
    _, still_in_string = _strip_docstring_line(tail, true)
    return prefix, still_in_string
end

function _strip_string_literals(line::AbstractString)
    io = IOBuffer()
    in_string = false
    escaped = false

    for c in line
        if in_string
            if escaped
                escaped = false
                print(io, ' ')
            elseif c == '\\'
                escaped = true
                print(io, ' ')
            elseif c == '"'
                in_string = false
                print(io, ' ')
            else
                print(io, ' ')
            end
        else
            if c == '"'
                in_string = true
                print(io, ' ')
            else
                print(io, c)
            end
        end
    end

    return String(take!(io))
end

function _strip_comment(line::AbstractString)
    idx = findfirst('#', line)
    isnothing(idx) && return String(line)
    return String(line[1:(idx - 1)])
end

function _line_uses_index_from_length(line::AbstractString)
    loop_pattern = r"\bfor\b[^\n]*\b(?:in|=)\s*\d+\s*:\s*(?:length|size)\s*\("
    range_index_pattern = r"\b\w+\s*\[[^\]\n]*:\s*(?:length|size)\s*\("
    scalar_index_pattern = r"\b\w+\s*\[\s*(?:length|size)\s*\("
    return occursin(loop_pattern, line) ||
           occursin(range_index_pattern, line) ||
           occursin(scalar_index_pattern, line)
end

function _function_signature_violations(
    signature::AbstractString,
    function_name::AbstractString,
    function_line::Int,
    file::String,
)
    violations = RuleViolation[]

    open_idx = findfirst('(', signature)
    close_idx = findlast(')', signature)
    if isnothing(open_idx) || isnothing(close_idx) || open_idx >= close_idx
        return violations
    end
    first_param_idx = nextind(signature, open_idx)
    first_param_idx >= close_idx && return violations
    last_param_idx = prevind(signature, close_idx)
    params = signature[first_param_idx:last_param_idx]

    for m in eachmatch(r"([A-Za-z_]\w*)\s*::\s*([A-Za-z_]\w*)", params)
        arg_name = String(m.captures[1])
        arg_type = String(m.captures[2])
        if _is_integer_like_type(arg_type) && _has_redundant_quantity_word(arg_name)
            message = "name '$arg_name' redundantly encodes quantity for an integer-typed argument"
            hint = "prefer type-driven naming, e.g. '$(_compact_int_name(arg_name))::$arg_type'"
            push!(
                violations,
                RuleViolation(
                    :redundant_int_quantity_name,
                    file,
                    String(function_name),
                    function_line,
                    function_line,
                    message,
                    hint,
                ),
            )
        end
    end
    return violations
end

function _is_integer_like_type(type_name::AbstractString)
    return type_name in (
        "Int",
        "Int8",
        "Int16",
        "Int32",
        "Int64",
        "Int128",
        "UInt",
        "UInt8",
        "UInt16",
        "UInt32",
        "UInt64",
        "UInt128",
        "Integer",
        "Signed",
        "Unsigned",
    )
end

function _has_redundant_quantity_word(name::AbstractString)
    low = lowercase(String(name))
    _is_plain_quantity_name(low) && return false
    return !isnothing(match(r"(^|_)(count|size|length|num|number|qty|quantity|total)(_|$)", low))
end

function _compact_int_name(name::AbstractString)
    low = lowercase(String(name))
    compact = replace(low, r"(^|_)(count|size|length|num|number|qty|quantity|total)(_|$)" => "_")
    compact = replace(compact, r"__+" => "_")
    compact = strip(compact, '_')
    return isempty(compact) ? "value" : compact
end

function _is_plain_quantity_name(name::AbstractString)
    return lowercase(String(name)) in (
        "count",
        "size",
        "length",
        "num",
        "number",
        "qty",
        "quantity",
        "total",
    )
end

function _function_name_from_definition(line::AbstractString)
    match_obj = match(r"^\s*function\s+([A-Za-z_]\w*[!]?)(?:\s*\(|\s*$)", line)
    if isnothing(match_obj)
        return nothing
    end
    return String(match_obj.captures[1])
end

function _is_top_level_loop(line::AbstractString)
    return !isnothing(match(r"^\s*(for|while)\b", line))
end

function _block_delta(line::AbstractString)
    opens = 0

    opens += _count_keyword(line, "function")
    opens += _count_keyword(line, "for")
    opens += _count_keyword(line, "while")
    opens += _count_keyword(line, "if")
    opens += _count_keyword(line, "let")
    opens += _count_keyword(line, "begin")
    opens += _count_keyword(line, "try")
    opens += _count_keyword(line, "quote")
    opens += _count_keyword(line, "struct")
    opens += _count_keyword(line, "module")
    opens += _count_keyword(line, "mutable struct")
    opens += _count_keyword(line, "baremodule")

    closes = _count_keyword(line, "end")
    return opens - closes
end

function _count_keyword(line::AbstractString, keyword::AbstractString)
    pattern = keyword == "mutable struct" ? r"\bmutable\s+struct\b" : Regex("\\b$(keyword)\\b")
    return length(collect(eachmatch(pattern, line)))
end

end
