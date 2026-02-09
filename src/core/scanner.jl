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
    return String(line[1:(idx - 1)])
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
