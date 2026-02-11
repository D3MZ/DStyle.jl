function check_simple_verb_redefinition(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    definitions = collectfunctiondefinitions(source)
    violations = RuleViolation[]

    foreach(definitions) do definition
        definition.islong && return

        call = parsecall(definition.body)
        isnothing(call) && return
        call.short == definition.shortname && return

        forwards(call.args, definition.args) || return

        push!(
            violations,
            RuleViolation(
                :simple_verb_redefinition,
                String(file),
                definition.name,
                definition.line,
                definition.line,
                "function is a direct alias of `$(call.name)` with unchanged arguments",
                "call `$(call.name)` directly instead of introducing alias verb `$(definition.name)`",
            ),
        )
    end

    return violations
end

function parsecall(body)
    expr = unwrapblockexpr(body)
    !(expr isa Expr) && return nothing
    expr.head != :call && return nothing

    name = rendername(expr.args[1])
    short = shortname(expr.args[1])
    isnothing(name) && return nothing
    isnothing(short) && return nothing

    args = flattenargs(expr.args[2:end])
    return (name = String(something(name)), short = String(something(short)), args = args)
end

function unwrapblockexpr(node)
    if node isa Expr && node.head == :block
        for arg in node.args
            if arg isa Expr
                return arg
            end
            if arg isa Symbol
                return arg
            end
        end
        return nothing
    end
    return node
end

function flattenargs(parts)
    positional = Any[]
    keywords = Any[]
    foreach(parts) do part
        if part isa Expr && part.head == :parameters
            foreach(part.args) do kw
                push!(keywords, kw)
            end
        else
            push!(positional, part)
        end
    end
    return [positional..., keywords...]
end

function forwards(
    callargs,
    declaredargs::AbstractVector,
)
    argnames = map(arg -> Symbol(arg.name), declaredargs)
    length(callargs) == length(argnames) || return false

    return all(eachindex(argnames)) do index
        sameargument(callargs[index], argnames[index])
    end
end

function sameargument(callarg, argname::Symbol)
    if callarg == argname
        return true
    end

    if callarg isa Expr && callarg.head == :... && length(callarg.args) == 1
        return callarg.args[1] == argname
    end

    if callarg isa Expr && callarg.head == :kw && length(callarg.args) == 2
        return callarg.args[1] == argname && callarg.args[2] == argname
    end

    return false
end
