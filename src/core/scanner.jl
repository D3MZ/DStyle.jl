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

function lineusesindexfromlength(line::AbstractString)
    looppattern = r"\bfor\b[^\n]*\b(?:in|=)\s*\d+\s*:\s*(?:length|size)\s*\("
    rangeindexpattern = r"\b\w+\s*\[[^\]\n]*:\s*(?:length|size)\s*\("
    scalarindexpattern = r"\b\w+\s*\[\s*(?:length|size)\s*\("
    return occursin(looppattern, line) ||
           occursin(rangeindexpattern, line) ||
           occursin(scalarindexpattern, line)
end

function functionnamefromdefinition(line::AbstractString)
    matchobj = match(r"^\s*function\s+([A-Za-z_]\w*[!]?)(?:\s*\(|\s*$)", line)
    if isnothing(matchobj)
        return nothing
    end
    return String(matchobj.captures[1])
end

function istoplevelloop(line::AbstractString)
    return !isnothing(match(r"^\s*(for|while)\b", line))
end

function countkeyword(line::AbstractString, keyword::AbstractString)
    pattern = keyword == "mutable struct" ? r"\bmutable\s+struct\b" : Regex("\\b$(keyword)\\b")
    return length(collect(eachmatch(pattern, line)))
end

function blockdelta(line::AbstractString)
    opens = 0

    opens += countkeyword(line, "function")
    opens += countkeyword(line, "for")
    opens += countkeyword(line, "while")
    opens += countkeyword(line, "if")
    opens += countkeyword(line, "let")
    opens += countkeyword(line, "begin")
    opens += countkeyword(line, "try")
    opens += countkeyword(line, "quote")
    opens += countkeyword(line, "struct")
    opens += countkeyword(line, "module")
    opens += countkeyword(line, "mutable struct")
    opens += countkeyword(line, "baremodule")

    closes = countkeyword(line, "end")
    return opens - closes
end

function uppercamelcase(name::AbstractString)
    return occursin(r"^[A-Z][A-Za-z0-9]*$", String(name))
end

function collectdeclaredtypenames(source::AbstractString)
    names = Set{String}()
    lines = split(source, '\n')

    foreach(lines) do rawline
        codeline = stripcomment(rawline)
        isempty(strip(codeline)) && return

        normalized = replace(codeline, r"^\s*(?:@[\w\.!]+\s+)+" => "")

        structmatch = match(r"^\s*(?:mutable\s+)?struct\s+([A-Za-z_]\w*)\b", normalized)
        if !isnothing(structmatch)
            push!(names, String(structmatch.captures[1]))
            return
        end

        abstractmatch = match(r"^\s*abstract\s+type\s+([A-Za-z_]\w*)\b", normalized)
        if !isnothing(abstractmatch)
            push!(names, String(abstractmatch.captures[1]))
            return
        end

        primitivematch = match(r"^\s*primitive\s+type\s+([A-Za-z_]\w*)\b", normalized)
        if !isnothing(primitivematch)
            push!(names, String(primitivematch.captures[1]))
            return
        end

        constgenericaliasmatch = match(r"^\s*const\s+([A-Za-z_]\w*)\s*\{[^=]+\}\s*=", normalized)
        if !isnothing(constgenericaliasmatch)
            push!(names, String(constgenericaliasmatch.captures[1]))
            return
        end

        constaliasmatch = match(
            r"^\s*const\s+([A-Za-z_]\w*)\s*=\s*(?:[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*|Union|Tuple|NamedTuple)\b",
            normalized,
        )
        if !isnothing(constaliasmatch)
            push!(names, String(constaliasmatch.captures[1]))
            return
        end
    end

    return names
end

function parenthesizedsegment(text::AbstractString, openindex::Int)
    depth = 0
    index = openindex

    while index <= lastindex(text)
        c = text[index]
        if c == '('
            depth += 1
        elseif c == ')'
            depth -= 1
            if depth == 0
                return String(text[openindex:index])
            end
        end
        index = nextind(text, index)
    end

    return nothing
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

function findtoplevelassignindex(line::AbstractString)
    isempty(line) && return nothing

    parendepth = 0
    bracketdepth = 0
    bracedepth = 0
    index = firstindex(line)

    while index <= lastindex(line)
        c = line[index]
        if c == '('
            parendepth += 1
        elseif c == ')'
            parendepth = max(parendepth - 1, 0)
        elseif c == '['
            bracketdepth += 1
        elseif c == ']'
            bracketdepth = max(bracketdepth - 1, 0)
        elseif c == '{'
            bracedepth += 1
        elseif c == '}'
            bracedepth = max(bracedepth - 1, 0)
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

        index = nextind(line, index)
    end

    return nothing
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
