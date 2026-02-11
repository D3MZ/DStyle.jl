"""
    check_function_name_lowercase(source; file="<memory>", constructor_names=nothing)

Checks that function names use lowercase/squashed words. Constructors are exempt.
"""
function check_function_name_lowercase(
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

        if occursin(r"[A-Z]", basename)
            suggestion = lowercase(basename) * (endswith(short, "!") ? "!" : "")
            push!(
                violations,
                RuleViolation(
                    :function_name_lowercase,
                    String(file),
                    name,
                    definition.line,
                    definition.line,
                    "function name `$name` must use lowercase squashed words",
                    "constructors are exempt; rename to lowercase, for example `$suggestion`",
                ),
            )
        end
    end

    return violations
end
