function check_simple_verb_redefinition(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    lines = split(source, '\n')
    violations = RuleViolation[]

    foreach(pairs(lines)) do (linenumber, rawline)
        codeline = stripcomment(rawline)
        isempty(strip(codeline)) && return

        declaration = parsefunctiondeclaration(codeline)
        isnothing(declaration) && return
        declaration.islong && return

        body = strip(String(something(declaration.body, "")))
        call = parsecall(body)
        isnothing(call) && return

        if call.short == declaration.name
            return
        end

        args = parsefunctionarguments(declaration.args)
        !forwards(call.args, args) && return

        push!(
            violations,
            RuleViolation(
                :simple_verb_redefinition,
                String(file),
                declaration.name,
                linenumber,
                linenumber,
                "function is a direct alias of `$(call.name)` with unchanged arguments",
                "call `$(call.name)` directly instead of introducing alias verb `$(declaration.name)`",
            ),
        )
    end

    return violations
end

function parsecall(body::AbstractString)
    expr = parseexpr(body)
    isnothing(expr) && return nothing
    !(expr isa Expr) && return nothing
    expr.head != :call && return nothing

    name = rendername(expr.args[1])
    short = shortname(expr.args[1])
    isnothing(name) && return nothing
    isnothing(short) && return nothing

    args = flattenargs(expr.args[2:end])
    return (name = something(name), short = something(short), args = args)
end

function parseexpr(text::AbstractString)
    source = strip(String(text))
    isempty(source) && return nothing

    expr = try
        Meta.parse(source)
    catch
        nothing
    end
    isnothing(expr) && return nothing

    if expr isa Expr && expr.head == :error
        return nothing
    end
    return expr
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

function rendername(node)
    if node isa Symbol
        return String(node)
    end
    if node isa Expr && node.head == :. && length(node.args) == 2
        left = rendername(node.args[1])
        right = renderfield(node.args[2])
        if isnothing(left) || isnothing(right)
            return nothing
        end
        return "$(something(left)).$(something(right))"
    end
    return nothing
end

function shortname(node)
    if node isa Symbol
        return String(node)
    end
    if node isa Expr && node.head == :. && length(node.args) == 2
        return renderfield(node.args[2])
    end
    return nothing
end

function renderfield(node)
    if node isa Symbol
        return String(node)
    end
    if node isa QuoteNode && node.value isa Symbol
        return String(node.value)
    end
    if node isa QuoteNode && node.value isa Expr
        expr = node.value
        if expr.head == :quote && length(expr.args) == 1 && expr.args[1] isa Symbol
            return String(expr.args[1])
        end
    end
    return nothing
end
