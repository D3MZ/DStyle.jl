"""
    check_field_name_type_repetition(source; file="<memory>")

Checks struct fields and typed function arguments for repeated type names.
"""
function check_field_name_type_repetition(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    violations = RuleViolation[]
    tree = parsesourcetree(source)
    if isnothing(tree)
        return checkfieldrepetitionfallback(source; file = file)
    end
    collectfieldrepetitionviolations!(tree, violations, String(file), 1)

    definitions = collectfunctiondefinitions(source)
    foreach(definitions) do definition
        occursin('.', definition.name) && return
        args = definition.args
        repeated = filter(arg -> argrepeatsargtype(arg), args)
        isempty(repeated) && return

        suggestion = concisefunctionsignature(definition.shortname, args, repeated)
        push!(
            violations,
            RuleViolation(
                :field_name_type_repetition,
                String(file),
                definition.name,
                definition.line,
                definition.line,
                "typed argument names repeat their type names",
                "use concise names that rely on dispatch, for example `$suggestion`",
            ),
        )
    end

    return violations
end

function checkfieldrepetitionfallback(
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
                structdepth[] = 1
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

            if occursin(r"^\s*end\b", codeline)
                instruct[] = false
                structname[] = ""
                structstem[] = ""
                structline[] = 0
                structdepth[] = 0
            end
        end

        declaration = parsefunctiondeclaration(codeline)
        isnothing(declaration) && return
        occursin('.', declaration.name) && return

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

function collectfieldrepetitionviolations!(node, violations, file::String, line::Int)
    currentline = line

    if node isa LineNumberNode
        return sourceline(node)
    end

    if node isa Expr
        if node.head == :struct && length(node.args) >= 3
            structname = extracttypename(node.args[2])
            if !isnothing(structname)
                structline = currentline
                structstem = lowercase(String(something(structname)))
                collectstructfieldviolations!(
                    node.args[3],
                    violations,
                    file,
                    structline,
                    String(something(structname)),
                    structstem,
                    structline,
                )
            end
        end

        foreach(node.args) do arg
            currentline = collectfieldrepetitionviolations!(arg, violations, file, currentline)
        end
        return currentline
    end

    if node isa QuoteNode && node.value isa Expr
        return collectfieldrepetitionviolations!(node.value, violations, file, currentline)
    end

    return currentline
end

function collectstructfieldviolations!(
    body,
    violations,
    file::String,
    structline::Int,
    structname::String,
    structstem::String,
    line::Int,
)
    currentline = line

    if !(body isa Expr) || body.head != :block
        return currentline
    end

    foreach(body.args) do field
        if field isa LineNumberNode
            currentline = sourceline(field)
            return
        end

        fieldname = structfieldname(field)
        if isnothing(fieldname)
            return
        end

        if fieldrepeatsstruct(String(something(fieldname)), structstem)
            suggestion = simplifyfieldname(String(something(fieldname)), structstem)
            push!(
                violations,
                RuleViolation(
                    :field_name_type_repetition,
                    file,
                    structname,
                    structline,
                    currentline,
                    "field `$(String(something(fieldname)))` repeats type name `$structname`",
                    "rename field to avoid repeating type stem, for example `$suggestion`",
                ),
            )
        end
    end

    return currentline
end

function structfieldname(node)
    if node isa Symbol
        return String(node)
    end
    if node isa Expr && node.head == :(::) && !isempty(node.args)
        return node.args[1] isa Symbol ? String(node.args[1]) : nothing
    end
    return nothing
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
