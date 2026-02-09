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

    infunction = false
    functionname = ""
    functionline = 0
    firstloopline = 0
    depth = 0

    for (linenumber, rawline) in pairs(lines)
        codeline = stripcomment(rawline)
        isempty(strip(codeline)) && continue

        if !infunction
            name = functionnamefromdefinition(codeline)
            if !isnothing(name)
                infunction = true
                functionname = something(name)
                functionline = linenumber
                firstloopline = 0
                depth = blockdelta(codeline)
                continue
            end
        else
            if firstloopline == 0 && istoplevelloop(codeline)
                firstloopline = linenumber
            end

            depth += blockdelta(codeline)
            if depth <= 0
                if firstloopline > 0
                    distance = firstloopline - functionline
                    if distance > max_lines_from_signature
                        message = "first loop starts $distance lines after function signature (max: $max_lines_from_signature)"
                        hint = "extract the loop into a kernel helper function and call it from $functionname"
                        push!(
                            violations,
                            RuleViolation(
                                :kernel_function_barrier,
                                String(file),
                                functionname,
                                functionline,
                                firstloopline,
                                message,
                                hint,
                            ),
                        )
                    end
                end
                infunction = false
            end
        end
    end

    return violations
end
