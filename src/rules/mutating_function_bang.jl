"""
    check_mutating_function_bang(source; file="<memory>", constructor_names=nothing)

Checks that functions mutating at least one argument end with `!`.
"""
function check_mutating_function_bang(
    source::AbstractString;
    file::AbstractString = "<memory>",
    constructor_names::Union{Nothing, AbstractVector{<:AbstractString}, AbstractSet{<:AbstractString}} = nothing,
)
    lines = split(source, '\n')
    typenames = collectdeclaredtypenames(source)
    if !isnothing(constructor_names)
        foreach(constructor_names) do name
            push!(typenames, String(name))
        end
    end
    violations = RuleViolation[]

    infunction = Ref(false)
    functionname = Ref("")
    functionline = Ref(0)
    functionargs = Ref(String[])
    depth = Ref(0)
    mutationline = Ref(0)

    foreach(pairs(lines)) do (linenumber, rawline)
        codeinput = stripcomment(rawline)
        codeline = stripstringliterals(codeinput)
        isempty(strip(codeline)) && return

        if !infunction[]
            declaration = parsefunctiondeclaration(codeline)
            isnothing(declaration) && return

            name = declaration.name
            basename = replace(name, "!" => "")
            args = parsefunctionarguments(declaration.args)
            argnames = map(arg -> arg.name, args)

            if declaration.islong
                infunction[] = true
                functionname[] = name
                functionline[] = linenumber
                functionargs[] = argnames
                depth[] = blockdelta(codeline)
                mutationline[] = 0
                return
            end

            bodyline = declaration.body
            bodymutates = linecontainsargmutation(bodyline, argnames)
            if bodymutates && !endswith(name, "!") && !(basename in typenames)
                push!(
                    violations,
                    RuleViolation(
                        :mutating_function_bang,
                        String(file),
                        name,
                        linenumber,
                        linenumber,
                        "function mutates argument(s) but name does not end with `!`",
                        "rename `$name` to `$(name)!`",
                    ),
                )
            end
            return
        end

        if mutationline[] == 0 && linecontainsargmutation(codeline, functionargs[])
            mutationline[] = linenumber
        end

        depth[] += blockdelta(codeline)
        if depth[] <= 0
            basename = replace(functionname[], "!" => "")
            if mutationline[] > 0 && !endswith(functionname[], "!") && !(basename in typenames)
                push!(
                    violations,
                    RuleViolation(
                        :mutating_function_bang,
                        String(file),
                        functionname[],
                        functionline[],
                        mutationline[],
                        "function mutates argument(s) but name does not end with `!`",
                        "rename `$(functionname[])` to `$(functionname[])!`",
                    ),
                )
            end

            infunction[] = false
            functionname[] = ""
            functionline[] = 0
            functionargs[] = String[]
            depth[] = 0
            mutationline[] = 0
        end
    end

    return violations
end

function linecontainsargmutation(line::AbstractString, argnames::AbstractVector{<:AbstractString})
    return any(argname -> linemutatesarg(line, argname), argnames)
end

function linemutatesarg(line::AbstractString, argname::AbstractString)
    indexassign = Regex("\\b$(argname)\\s*\\[[^\\n\\]]*\\]\\s*(?:[+\\-*/\\\\.^%&|]?=)(?!=)")
    fieldassign = Regex("\\b$(argname)\\s*\\.\\s*[A-Za-z_]\\w*\\s*(?:[+\\-*/\\\\.^%&|]?=)(?!=)")
    dotassign = Regex("\\b$(argname)\\s*\\.\\s*(?:[+\\-*/\\\\.^%&|]?=)(?!=)")
    mutcall = Regex("\\b\\w+!\\s*\\(\\s*$(argname)\\b")

    return occursin(indexassign, line) ||
           occursin(fieldassign, line) ||
           occursin(dotassign, line) ||
           occursin(mutcall, line)
end
