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
    violations = RuleViolation[]
    definitions = collectfunctiondefinitions(source)

    foreach(definitions) do definition
        definition.islong || return

        firstloopline = firsttoplevelloopline(definition.body, definition.line)
        firstloopline == 0 && return

        distance = firstloopline - definition.line
        if distance > max_lines_from_signature
            message = "first loop starts $distance lines after function signature (max: $max_lines_from_signature)"
            hint = "extract the loop into a kernel helper function and call it from $(definition.shortname)"
            push!(
                violations,
                RuleViolation(
                    :kernel_function_barrier,
                    String(file),
                    definition.shortname,
                    definition.line,
                    firstloopline,
                    message,
                    hint,
                ),
            )
        end
    end

    return violations
end

function firsttoplevelloopline(body, line::Int)
    if body isa Expr && (body.head == :for || body.head == :while)
        return line
    end
    if !(body isa Expr) || body.head != :block
        return 0
    end

    state = foldl(body.args; init = (line = line, found = 0)) do acc, statement
        acc.found > 0 && return acc
        if statement isa LineNumberNode
            return (line = sourceline(statement), found = 0)
        end
        if statement isa Expr && (statement.head == :for || statement.head == :while)
            return (line = acc.line, found = acc.line)
        end
        return acc
    end
    return state.found
end
