"""
    check_mutating_function_bang(source; file="<memory>", constructor_names=nothing)

Checks that functions mutating at least one argument end with `!`.
"""
function check_mutating_function_bang(
    source::AbstractString;
    file::AbstractString = "<memory>",
    constructor_names::Union{Nothing, AbstractVector{<:AbstractString}, AbstractSet{<:AbstractString}} = nothing,
    ignore::Union{Nothing, AbstractVector{<:AbstractString}, AbstractSet{<:AbstractString}} = nothing,
)
    typenames = collectdeclaredtypenames(source)
    if !isnothing(constructor_names)
        foreach(constructor_names) do name
            push!(typenames, String(name))
        end
    end
    ignored = normalizeignoreset(ignore)
    violations = RuleViolation[]
    definitions = collectfunctiondefinitions(source)

    foreach(definitions) do definition
        name = definition.name
        short = definition.shortname
        basename = replace(short, "!" => "")
        if basename in typenames
            return
        end
        if functionisignored(name, short, ignored)
            return
        end
        if endswith(short, "!")
            return
        end

        argnames = Set{String}(map(arg -> arg.name, definition.args))
        isempty(argnames) && return

        mutationline = firstmutationline!(definition.body, argnames, definition.line)
        if mutationline > 0
            push!(
                violations,
                RuleViolation(
                    :mutating_function_bang,
                    String(file),
                    name,
                    definition.line,
                    mutationline,
                    "function mutates argument(s) but name does not end with `!`",
                    "rename `$name` to `$(name)!`",
                ),
            )
        end
    end

    return violations
end

function firstmutationline!(body, argnames::Set{String}, line::Int)
    mutationline, _ = firstmutationlinevisit(body, argnames, line)
    return mutationline
end

function firstmutationlinevisit(node, argnames::Set{String}, line::Int)
    currentline = line

    if node isa LineNumberNode
        return 0, sourceline(node)
    end

    if node isa Expr
        nesteddefinition = parsefunctiondefinition(node, currentline)
        if !isnothing(nesteddefinition)
            return 0, currentline
        end

        if expressionmutatesargs(node, argnames)
            return currentline, currentline
        end

        for arg in node.args
            mutationline, nextline = firstmutationlinevisit(arg, argnames, currentline)
            if mutationline > 0
                return mutationline, nextline
            end
            currentline = nextline
        end

        return 0, currentline
    end

    if node isa QuoteNode && node.value isa Expr
        return firstmutationlinevisit(node.value, argnames, currentline)
    end

    return 0, currentline
end

function expressionmutatesargs(node::Expr, argnames::Set{String})
    if assignmentmutatesargs(node, argnames)
        return true
    end
    if callmutatesargs(node, argnames)
        return true
    end
    return false
end

function assignmentmutatesargs(node::Expr, argnames::Set{String})
    if isempty(node.args)
        return false
    end

    headtext = String(node.head)
    if !endswith(headtext, "=")
        return false
    end
    lhs = node.args[1]

    if startswith(headtext, ".")
        lhsname = argnamefromnode(lhs)
        return !isnothing(lhsname) && (String(something(lhsname)) in argnames)
    end

    if node.head == :(=) || node.head == Symbol("+=") || node.head == Symbol("-=") ||
       node.head == Symbol("*=") || node.head == Symbol("/=") || node.head == Symbol("\\=") ||
       node.head == Symbol("^=") || node.head == Symbol("%=") || node.head == Symbol("|=") ||
       node.head == Symbol("&=")
        return lhsmutatesargs(lhs, argnames)
    end

    return false
end

function lhsmutatesargs(lhs, argnames::Set{String})
    if lhs isa Expr && lhs.head == :ref && !isempty(lhs.args)
        target = argnamefromnode(lhs.args[1])
        return !isnothing(target) && (String(something(target)) in argnames)
    end

    if lhs isa Expr && lhs.head == :. && !isempty(lhs.args)
        target = argnamefromnode(lhs.args[1])
        return !isnothing(target) && (String(something(target)) in argnames)
    end

    return false
end

function callmutatesargs(node::Expr, argnames::Set{String})
    if node.head != :call || isempty(node.args)
        return false
    end

    name = shortname(node.args[1])
    if isnothing(name)
        return false
    end
    callname = String(something(name))
    if !occursin(r"^[A-Za-z_]\w*!$", callname)
        return false
    end

    return any(node.args[2:end]) do arg
        argname = argnamefromnode(arg)
        return !isnothing(argname) && (String(something(argname)) in argnames)
    end
end

function argnamefromnode(node)
    if node isa Symbol
        return String(node)
    end
    if node isa Expr && node.head == :... && length(node.args) == 1
        return argnamefromnode(node.args[1])
    end
    if node isa Expr && node.head == :kw && length(node.args) == 2
        return argnamefromnode(node.args[2])
    end
    return nothing
end
