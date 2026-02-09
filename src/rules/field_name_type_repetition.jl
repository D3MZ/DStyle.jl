"""
    check_field_name_type_repetition(source; file="<memory>")

Checks struct fields and typed function arguments for repeated type names.
"""
function check_field_name_type_repetition(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    lines = split(source, '\n')
    violations = RuleViolation[]

    instruct = Ref(false)
    structname = Ref("")
    structstem = Ref("")
    structline = Ref(0)
    structdepth = Ref(0)

    foreach(pairs(lines)) do (linenumber, rawline)
        codeline = stripcomment(rawline)
        isempty(strip(codeline)) && return

        if !instruct[]
            structmatch = match(r"^\s*(?:mutable\s+)?struct\s+([A-Za-z_]\w*)\b", codeline)
            if !isnothing(structmatch)
                name = String(structmatch.captures[1])
                instruct[] = true
                structname[] = name
                structstem[] = lowercase(name)
                structline[] = linenumber
                structdepth[] = blockdelta(codeline)
                return
            end
        else
            fieldmatch = match(r"^\s*([A-Za-z_]\w*)\s*(?::|$)", codeline)
            if !isnothing(fieldmatch)
                fieldname = String(fieldmatch.captures[1])
                if fieldrepeatsstruct(fieldname, structstem[])
                    suggestion = simplifyfieldname(fieldname, structstem[])
                    push!(
                        violations,
                        RuleViolation(
                            :field_name_type_repetition,
                            String(file),
                            structname[],
                            structline[],
                            linenumber,
                            "field `$fieldname` repeats type name `$(structname[])`",
                            "rename field to avoid repeating type stem, for example `$suggestion`",
                        ),
                    )
                end
            end

            structdepth[] += blockdelta(codeline)
            if structdepth[] <= 0
                instruct[] = false
                structname[] = ""
                structstem[] = ""
                structline[] = 0
                structdepth[] = 0
            end
        end

        declaration = parsefunctiondeclaration(codeline)
        isnothing(declaration) && return

        args = parsefunctionarguments(declaration.args)
        repeated = filter(arg -> argrepeatsargtype(arg), args)
        isempty(repeated) && return

        suggestion = concisefunctionsignature(declaration.name, args, repeated)
        push!(
            violations,
            RuleViolation(
                :field_name_type_repetition,
                String(file),
                declaration.name,
                linenumber,
                linenumber,
                "typed argument names repeat their type names",
                "use concise names that rely on dispatch, for example `$suggestion`",
            ),
        )
    end

    return violations
end

function fieldrepeatsstruct(fieldname::AbstractString, structstem::AbstractString)
    return startswith(lowercase(String(fieldname)), lowercase(String(structstem)))
end

function simplifyfieldname(fieldname::AbstractString, structstem::AbstractString)
    lowered = lowercase(String(fieldname))
    stem = lowercase(String(structstem))
    if startswith(lowered, stem)
        trimmed = lowered[(length(stem) + 1):end]
        isempty(trimmed) && return "value"
        return trimmed
    end
    return lowered
end

function argrepeatsargtype(arg)
    isnothing(arg.type) && return false
    return lowercase(arg.name) == lowercase(String(something(arg.type)))
end

function concisefunctionsignature(
    originalname::AbstractString,
    args::AbstractVector,
    repeatedargs::AbstractVector,
)
    compactname = concisefunctionname(originalname, repeatedargs)
    used = Set{String}()

    rendered = map(args) do arg
        argname = arg.name
        if any(rep -> rep.name == arg.name && rep.type == arg.type, repeatedargs)
            argname = compactargname!(arg.name, used)
        end

        if isnothing(arg.type)
            return argname
        end
        return "$(argname)::$(String(something(arg.type)))"
    end

    return "$(compactname)($(join(rendered, ", ")))"
end

function concisefunctionname(originalname::AbstractString, repeatedargs::AbstractVector)
    hasbang = endswith(String(originalname), "!")
    basename = replace(String(originalname), "!" => "")
    compact = basename

    foreach(repeatedargs) do arg
        compact = trimsuffixignorecase(compact, arg.name)
        if !isnothing(arg.type)
            compact = trimsuffixignorecase(compact, String(something(arg.type)))
        end
    end

    if compact == basename && startswith(lowercase(basename), "get") && length(basename) > 3
        compact = "get"
    end
    isempty(compact) && (compact = "f")

    return hasbang ? "$(compact)!" : compact
end

function trimsuffixignorecase(text::AbstractString, suffix::AbstractString)
    lowered = lowercase(String(text))
    lowersuffix = lowercase(String(suffix))
    if endswith(lowered, lowersuffix)
        keep = length(text) - length(suffix)
        keep <= 0 && return ""
        return String(text[1:keep])
    end
    return String(text)
end

function compactargname!(argname::AbstractString, used::Set{String})
    base = lowercase(string(first(String(argname))))
    if !(base in used)
        push!(used, base)
        return base
    end

    candidate = nextavailablecompactname(base, 2, used)
    push!(used, candidate)
    return candidate
end

function nextavailablecompactname(base::AbstractString, suffix::Int, used::Set{String})
    candidate = "$(base)$(suffix)"
    if candidate in used
        return nextavailablecompactname(base, suffix + 1, used)
    end
    return candidate
end
