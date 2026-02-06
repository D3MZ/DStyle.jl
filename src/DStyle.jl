module DStyle

export RuleViolation, check_kernel_function_barriers, readme_badge, test_all

struct RuleViolation
    rule::Symbol
    file::String
    function_name::String
    function_line::Int
    loop_line::Int
    message::String
end

Base.show(io::IO, violation::RuleViolation) = print(
    io,
    "$(violation.file):$(violation.loop_line): $(violation.rule): $(violation.message)",
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
                        message = "first loop is $distance lines away from function signature (max $max_lines_from_signature)"
                        push!(
                            violations,
                            RuleViolation(
                                :kernel_function_barrier,
                                String(file),
                                function_name,
                                function_line,
                                first_loop_line,
                                message,
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
    test_all(; paths=nothing, max_lines_from_signature=1, throw=true)

Runs all currently implemented style checks (currently only kernel-function
barriers) over one or more Julia files.
"""
function test_all(;
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    max_lines_from_signature::Int = 1,
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
    end

    if throw && !isempty(violations)
        details = join(string.(violations), '\n')
        error("DStyle found style violations:\n$details")
    end

    return violations
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

function _strip_comment(line::AbstractString)
    idx = findfirst('#', line)
    isnothing(idx) && return String(line)
    return String(line[1:(idx - 1)])
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
