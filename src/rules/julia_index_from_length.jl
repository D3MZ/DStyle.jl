"""
    check_index_from_length(source; file="<memory>")

Reports lines that index or iterate using bounds derived from `length`/`size`,
for example `for i in 1:length(x)` or `x[1:size(x, 1)]`.
"""
function check_index_from_length(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    tree = parsesourcetree(source)
    violations = RuleViolation[]
    isnothing(tree) && return violations

    collectindexfromlengthviolations!(
        tree,
        violations,
        String(file),
        1,
        "<top-level>",
        0,
    )

    return violations
end

function collectindexfromlengthviolations!(
    node,
    violations,
    file::String,
    line::Int,
    functionname::String,
    functionline::Int,
)
    currentline = line
    currentname = functionname
    currentfunctionline = functionline

    if node isa LineNumberNode
        return sourceline(node), currentname, currentfunctionline
    end

    if node isa Expr
        definition = parsefunctiondefinition(node, currentline)
        if !isnothing(definition)
            if definition.islong
                collectindexfromlengthviolations!(
                    definition.body,
                    violations,
                    file,
                    definition.line,
                    definition.shortname,
                    definition.line,
                )
            else
                collectindexfromlengthviolations!(
                    definition.body,
                    violations,
                    file,
                    definition.line,
                    currentname,
                    currentfunctionline,
                )
            end
            return currentline, currentname, currentfunctionline
        end

        if exprusesindexfromlength(node)
            message = "indexing with indices obtained from length/size is discouraged (JuliaIndexFromLength)"
            hint = "use eachindex(array) or axes(array, dim) instead of 1:length(array)/1:size(array, dim)"
            push!(
                violations,
                RuleViolation(
                    :julia_index_from_length,
                    file,
                    currentname,
                    currentfunctionline,
                    currentline,
                    message,
                    hint,
                ),
            )
        end

        for arg in node.args
            nextline, nextname, nextfunctionline = collectindexfromlengthviolations!(
                arg,
                violations,
                file,
                currentline,
                currentname,
                currentfunctionline,
            )
            currentline = nextline
            currentname = nextname
            currentfunctionline = nextfunctionline
        end
        return currentline, currentname, currentfunctionline
    end

    if node isa QuoteNode && node.value isa Expr
        return collectindexfromlengthviolations!(
            node.value,
            violations,
            file,
            currentline,
            currentname,
            currentfunctionline,
        )
    end

    return currentline, currentname, currentfunctionline
end

function exprusesindexfromlength(node::Expr)
    if node.head == :for && !isempty(node.args)
        iterator = node.args[1]
        if iterator isa Expr && iterator.head == :(=) && length(iterator.args) == 2
            return israngefromlength(iterator.args[2])
        end
    end

    if node.head == :ref && length(node.args) >= 2
        for indexexpr in node.args[2:end]
            if islengthorsizecall(indexexpr) || israngefromlength(indexexpr)
                return true
            end
        end
    end

    return false
end

function israngefromlength(node)
    if !(node isa Expr) || node.head != :call || length(node.args) != 3
        return false
    end
    if node.args[1] != :(:)
        return false
    end
    if !(node.args[2] isa Integer)
        return false
    end
    return islengthorsizecall(node.args[3])
end

function islengthorsizecall(node)
    if !(node isa Expr) || node.head != :call || isempty(node.args)
        return false
    end
    name = shortname(node.args[1])
    if isnothing(name)
        return false
    end
    return String(something(name)) in ("length", "size")
end
