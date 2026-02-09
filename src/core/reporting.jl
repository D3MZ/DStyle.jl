function ruledisplayname(rule::Symbol)
    if rule == :kernel_function_barrier
        return "kernel function barrier"
    elseif rule == :julia_index_from_length
        return "JuliaIndexFromLength"
    else
        return String(rule)
    end
end

function displaypath(path::AbstractString)
    try
        relative = relpath(path, pwd())
        return startswith(relative, "..") ? String(path) : relative
    catch
        return String(path)
    end
end

function formatviolationreport(violations::AbstractVector{RuleViolation})
    isempty(violations) && return "DStyle found 0 violations."

    grouped = Dict{String, Vector{RuleViolation}}()
    for violation in violations
        bucket = get!(grouped, violation.file, RuleViolation[])
        push!(bucket, violation)
    end

    files = sort!(collect(keys(grouped)))
    rulename = ruledisplayname(violations[1].rule)
    header =
        "DStyle found $(length(violations)) $rulename violation(s) across $(length(files)) file(s):"
    lines = String[header]

    for file in files
        push!(lines, displaypath(file))
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
