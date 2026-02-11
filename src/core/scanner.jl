function stripdocstringline(line::AbstractString, inmultilinestring::Bool)
    text = String(line)
    idx = findfirst("\"\"\"", text)

    if inmultilinestring
        if isnothing(idx)
            return "", true
        end
        stop = last(idx)
        rest = stop < lastindex(text) ? text[(stop + 1):end] : ""
        return stripdocstringline(rest, false)
    end

    if isnothing(idx)
        return text, false
    end

    start = first(idx)
    stop = last(idx)
    prefix = start > firstindex(text) ? text[firstindex(text):(start - 1)] : ""
    tail = stop < lastindex(text) ? text[(stop + 1):end] : ""
    _, stillinstring = stripdocstringline(tail, true)
    return prefix, stillinstring
end

function stripstringliterals(line::AbstractString)
    io = IOBuffer()
    instring = false
    escaped = false

    foreach(line) do c
        if instring
            if escaped
                escaped = false
                print(io, ' ')
            elseif c == '\\'
                escaped = true
                print(io, ' ')
            elseif c == '"'
                instring = false
                print(io, ' ')
            else
                print(io, ' ')
            end
        else
            if c == '"'
                instring = true
                print(io, ' ')
            else
                print(io, c)
            end
        end
    end

    return String(take!(io))
end

function stripcomment(line::AbstractString)
    idx = findfirst('#', line)
    isnothing(idx) && return String(line)
    idx == firstindex(line) && return ""
    stop = prevind(line, idx)
    return String(line[firstindex(line):stop])
end

function parseexpr(text::AbstractString)
    source = strip(String(text))
    isempty(source) && return nothing

    expr = try
        Meta.parse(source; raise = false)
    catch
        nothing
    end
    isnothing(expr) && return nothing
    if expr isa Expr && (expr.head == :error || expr.head == :incomplete)
        return nothing
    end
    return expr
end

function parsesourcetree(source::AbstractString)
    wrapped = "begin\n$(String(source))\nend"
    expr = try
        Meta.parse(wrapped; raise = false)
    catch
        return nothing
    end
    if expr isa Expr && (expr.head == :error || expr.head == :incomplete)
        return nothing
    end
    return expr
end

function sourceline(line::Int)
    return max(line - 1, 1)
end

function sourceline(node::LineNumberNode)
    return sourceline(node.line)
end

function uppercamelcase(name::AbstractString)
    return occursin(r"^[A-Z][A-Za-z0-9]*$", String(name))
end

function simplifytypename(typespec::AbstractString)
    text = strip(String(typespec))
    if isempty(text)
        return nothing
    end

    if occursin('{', text)
        text = first(split(text, '{'; limit = 2))
    end
    if occursin('<', text)
        text = first(split(text, '<'; limit = 2))
    end
    if occursin(" where ", text)
        text = first(split(text, " where "; limit = 2))
    end
    if occursin('.', text)
        text = last(split(text, '.'))
    end

    text = strip(text)
    isempty(text) && return nothing
    return text
end

function parenthesizedsegment(text::AbstractString, openindex::Int)
    return parenthesizedsegmentstep(text, openindex, openindex, 0)
end

function parenthesizedsegmentstep(
    text::AbstractString,
    openindex::Int,
    index::Int,
    depth::Int,
)
    if index > lastindex(text)
        return nothing
    end

    c = text[index]
    nextdepth = if c == '('
        depth + 1
    elseif c == ')'
        depth - 1
    else
        depth
    end

    if c == ')' && nextdepth == 0
        return String(text[openindex:index])
    end

    return parenthesizedsegmentstep(text, openindex, nextind(text, index), nextdepth)
end

function findtoplevelassignindex(line::AbstractString)
    isempty(line) && return nothing
    return findtoplevelassignindexstep(line, firstindex(line), 0, 0, 0)
end

function findtoplevelassignindexstep(
    line::AbstractString,
    index::Int,
    parendepth::Int,
    bracketdepth::Int,
    bracedepth::Int,
)
    if index > lastindex(line)
        return nothing
    end

    c = line[index]
    nextparen = parendepth
    nextbracket = bracketdepth
    nextbrace = bracedepth

    if c == '('
        nextparen += 1
    elseif c == ')'
        nextparen = max(nextparen - 1, 0)
    elseif c == '['
        nextbracket += 1
    elseif c == ']'
        nextbracket = max(nextbracket - 1, 0)
    elseif c == '{'
        nextbrace += 1
    elseif c == '}'
        nextbrace = max(nextbrace - 1, 0)
    elseif c == '=' && parendepth == 0 && bracketdepth == 0 && bracedepth == 0
        previouschar = if index > firstindex(line)
            line[prevind(line, index)]
        else
            '\0'
        end
        nextchar = if index < lastindex(line)
            line[nextind(line, index)]
        else
            '\0'
        end

        if previouschar != '=' && nextchar != '=' && nextchar != '>'
            return index
        end
    end

    return findtoplevelassignindexstep(
        line,
        nextind(line, index),
        nextparen,
        nextbracket,
        nextbrace,
    )
end

function parsefunctiondeclaration(line::AbstractString)
    functionmatch = match(r"^\s*function\s+([A-Za-z_]\w*[!]?)\s*(?:\(|$)", line)
    if !isnothing(functionmatch)
        name = String(functionmatch.captures[1])
        openmatch = findfirst('(', line)
        args = isnothing(openmatch) ? nothing : parenthesizedsegment(line, openmatch)
        return (name = name, args = args, body = nothing, islong = true)
    end

    equalindex = findtoplevelassignindex(line)
    if isnothing(equalindex)
        return nothing
    end

    equalindex == firstindex(line) && return nothing
    leftstop = prevind(line, equalindex)
    left = strip(String(line[firstindex(line):leftstop]))
    if isempty(left)
        return nothing
    end
    if startswith(left, "if ") || startswith(left, "elseif ") || startswith(left, "for ") || startswith(left, "while ")
        return nothing
    end

    shortmatch = match(r"^([A-Za-z_]\w*[!]?)\s*\(", left)
    if isnothing(shortmatch)
        return nothing
    end

    name = String(shortmatch.captures[1])
    openmatch = findfirst('(', left)
    args = isnothing(openmatch) ? nothing : parenthesizedsegment(left, openmatch)
    body = if equalindex == lastindex(line)
        ""
    else
        bodystart = nextind(line, equalindex)
        strip(String(line[bodystart:lastindex(line)]))
    end
    return (name = name, args = args, body = body, islong = false)
end

function simplifytypename(node)
    if node isa Symbol
        return String(node)
    end
    if node isa QuoteNode && node.value isa Symbol
        return String(node.value)
    end
    if node isa Expr && node.head == :curly && !isempty(node.args)
        return simplifytypename(node.args[1])
    end
    if node isa Expr && node.head == :where && !isempty(node.args)
        return simplifytypename(node.args[1])
    end
    if node isa Expr && node.head == :<: && !isempty(node.args)
        return simplifytypename(node.args[1])
    end
    if node isa Expr && node.head == :>: && !isempty(node.args)
        return simplifytypename(node.args[1])
    end
    if node isa Expr && node.head == :.
        return shortname(node)
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

function signaturecall(signature)
    if signature isa Symbol
        return Expr(:call, signature)
    end
    if signature isa Expr && signature.head == :call
        return signature
    end
    if signature isa Expr && signature.head == :where && !isempty(signature.args)
        return signaturecall(signature.args[1])
    end
    if signature isa Expr && signature.head == :(::) && !isempty(signature.args)
        return signaturecall(signature.args[1])
    end
    return nothing
end

function shortdefinitioncall(signature)
    if signature isa Expr && signature.head == :call
        return signature
    end
    if signature isa Expr && signature.head == :where && !isempty(signature.args)
        return shortdefinitioncall(signature.args[1])
    end
    if signature isa Expr && signature.head == :(::) && !isempty(signature.args)
        return shortdefinitioncall(signature.args[1])
    end
    return nothing
end

function extracttypename(node)
    if node isa Symbol
        return String(node)
    end
    if node isa QuoteNode && node.value isa Symbol
        return String(node.value)
    end
    if node isa Expr && node.head == :curly && !isempty(node.args)
        return extracttypename(node.args[1])
    end
    if node isa Expr && node.head == :where && !isempty(node.args)
        return extracttypename(node.args[1])
    end
    if node isa Expr && node.head == :<: && !isempty(node.args)
        return extracttypename(node.args[1])
    end
    if node isa Expr && node.head == :>: && !isempty(node.args)
        return extracttypename(node.args[1])
    end
    if node isa Expr && node.head == :.
        return shortname(node)
    end
    return nothing
end

function istypealiasrhs(node)
    if node isa Symbol
        return true
    end
    if node isa Expr && (node.head == :. || node.head == :curly || node.head == :where)
        return true
    end
    if node isa Expr && node.head == :call && !isempty(node.args)
        name = shortname(node.args[1])
        return !isnothing(name) && (String(something(name)) in ("Union", "Tuple", "NamedTuple"))
    end
    return false
end

function collectconstalias!(node, names::Set{String})
    if !(node isa Expr) || node.head != :(=) || length(node.args) != 2
        return nothing
    end

    aliasname = extracttypename(node.args[1])
    if isnothing(aliasname)
        return nothing
    end
    if !istypealiasrhs(node.args[2])
        return nothing
    end

    push!(names, String(something(aliasname)))
    return nothing
end

function collectdeclaredtypenames(source::AbstractString)
    names = Set{String}()
    tree = parsesourcetree(source)
    isnothing(tree) && return names

    collectdeclaredtypenames!(tree, names, 1)
    return names
end

function collectdeclaredtypenames!(node, names::Set{String}, line::Int)
    currentline = line

    if node isa LineNumberNode
        return sourceline(node)
    end

    if node isa Expr
        if node.head == :struct && length(node.args) >= 2
            name = extracttypename(node.args[2])
            !isnothing(name) && push!(names, String(something(name)))
        elseif node.head == :abstract && !isempty(node.args)
            name = extracttypename(node.args[1])
            !isnothing(name) && push!(names, String(something(name)))
        elseif node.head == :primitive && !isempty(node.args)
            name = extracttypename(node.args[1])
            !isnothing(name) && push!(names, String(something(name)))
        elseif node.head == :const && !isempty(node.args)
            collectconstalias!(node.args[1], names)
        end

        foreach(node.args) do arg
            currentline = collectdeclaredtypenames!(arg, names, currentline)
        end
        return currentline
    end

    if node isa QuoteNode && node.value isa Expr
        return collectdeclaredtypenames!(node.value, names, currentline)
    end

    return currentline
end

function parsefunctionarguments(signature::Expr)
    if signature.head != :call
        return NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}[]
    end
    return parsefunctionarguments(signature.args[2:end])
end

function parsefunctionarguments(argspec::Union{Nothing, AbstractString})
    isnothing(argspec) && return NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}[]
    text = String(something(argspec))
    isempty(text) && return NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}[]
    if firstindex(text) == lastindex(text)
        return NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}[]
    end

    innerstart = nextind(text, firstindex(text))
    innerstop = prevind(text, lastindex(text))
    if innerstart > innerstop
        return NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}[]
    end
    inner = text[innerstart:innerstop]
    normalized = replace(inner, ';' => ',')
    parts = split(normalized, ',')
    args = NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}[]

    foreach(parts) do part
        token = strip(part)
        isempty(token) && return
        token = strip(first(split(token, '='; limit = 2)))
        isempty(token) && return

        namepart = token
        typepart = nothing
        if occursin("::", token)
            sides = split(token, "::"; limit = 2)
            namepart = strip(sides[1])
            typepart = simplifytypename(strip(sides[2]))
        end

        namepart = replace(namepart, "..." => "")
        namematch = match(r"^([A-Za-z_]\w*)$", namepart)
        isnothing(namematch) && return
        push!(
            args,
            (name = String(namematch.captures[1]), type = isnothing(typepart) ? nothing : String(typepart)),
        )
    end

    return args
end

function parsefunctionarguments(parts::AbstractVector)
    positional = NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}[]
    keywords = NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}[]

    foreach(parts) do part
        if part isa Expr && part.head == :parameters
            foreach(part.args) do kw
                binding = parseargumentbinding(kw)
                isnothing(binding) && return
                push!(keywords, something(binding))
            end
        else
            binding = parseargumentbinding(part)
            isnothing(binding) && return
            push!(positional, something(binding))
        end
    end

    return [positional..., keywords...]
end

function parseargumentbinding(node)
    target = node
    typeexpr = nothing

    if target isa Expr && target.head == :kw && length(target.args) == 2
        target = target.args[1]
    end
    if target isa Expr && target.head == :... && length(target.args) == 1
        target = target.args[1]
    end
    if target isa Expr && target.head == :(::) && length(target.args) == 2
        typeexpr = target.args[2]
        target = target.args[1]
    end

    argname = extractargumentname(target)
    isnothing(argname) && return nothing

    argtype = isnothing(typeexpr) ? nothing : simplifytypename(typeexpr)
    return (name = String(something(argname)), type = isnothing(argtype) ? nothing : String(something(argtype)))
end

function extractargumentname(node)
    if node isa Symbol
        return String(node)
    end
    if node isa Expr && node.head == :... && length(node.args) == 1
        return extractargumentname(node.args[1])
    end
    if node isa Expr && node.head == :kw && length(node.args) == 2
        return extractargumentname(node.args[1])
    end
    return nothing
end

function parsefunctiondefinition(node, line::Int)
    if node isa Expr && node.head == :function && length(node.args) == 2
        call = signaturecall(node.args[1])
        isnothing(call) && return nothing
        name = rendername(call.args[1])
        short = shortname(call.args[1])
        if isnothing(name) || isnothing(short)
            return nothing
        end
        return (
            name = String(something(name)),
            shortname = String(something(short)),
            args = parsefunctionarguments(something(call)),
            body = node.args[2],
            islong = true,
            line = line,
        )
    end

    if node isa Expr && node.head == :(=) && length(node.args) == 2
        call = shortdefinitioncall(node.args[1])
        isnothing(call) && return nothing
        name = rendername(call.args[1])
        short = shortname(call.args[1])
        if isnothing(name) || isnothing(short)
            return nothing
        end
        return (
            name = String(something(name)),
            shortname = String(something(short)),
            args = parsefunctionarguments(something(call)),
            body = node.args[2],
            islong = false,
            line = line,
        )
    end

    return nothing
end

function collectfunctiondefinitions(source::AbstractString)
    definitions = NamedTuple{
        (:name, :shortname, :args, :body, :islong, :line),
        Tuple{
            String,
            String,
            Vector{NamedTuple{(:name, :type), Tuple{String, Union{Nothing, String}}}},
            Any,
            Bool,
            Int,
        },
    }[]
    tree = parsesourcetree(source)
    isnothing(tree) && return definitions

    collectfunctiondefinitions!(tree, definitions, 1)
    return definitions
end

function collectfunctiondefinitions!(node, definitions, line::Int)
    currentline = line

    if node isa LineNumberNode
        return sourceline(node)
    end

    if node isa Expr
        definition = parsefunctiondefinition(node, currentline)
        !isnothing(definition) && push!(definitions, something(definition))

        foreach(node.args) do arg
            currentline = collectfunctiondefinitions!(arg, definitions, currentline)
        end
        return currentline
    end

    if node isa QuoteNode && node.value isa Expr
        return collectfunctiondefinitions!(node.value, definitions, currentline)
    end

    return currentline
end

function normalizeignoreset(
    ignore::Union{Nothing, AbstractVector{<:AbstractString}, AbstractSet{<:AbstractString}} = nothing,
)
    names = Set{String}()
    isnothing(ignore) && return names
    foreach(ignore) do name
        text = String(name)
        push!(names, text)
        push!(names, replace(text, "!" => ""))
    end
    return names
end

function functionisignored(
    fullname::AbstractString,
    short::AbstractString,
    ignoreset::AbstractSet{<:AbstractString},
)
    isempty(ignoreset) && return false

    candidates = Set{String}()
    push!(candidates, String(fullname))
    push!(candidates, replace(String(fullname), "!" => ""))
    push!(candidates, String(short))
    push!(candidates, replace(String(short), "!" => ""))

    if occursin('.', String(fullname))
        tail = last(split(String(fullname), '.'))
        push!(candidates, tail)
        push!(candidates, replace(tail, "!" => ""))
    end

    return any(candidate -> candidate in ignoreset, candidates)
end
