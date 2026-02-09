"""
    check_function_name_lowercase(source; file="<memory>")

Checks that function names use lowercase/squashed words. Constructors are exempt.
"""
function check_function_name_lowercase(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    lines = split(source, '\n')
    typenames = collectdeclaredtypenames(source)
    violations = RuleViolation[]

    foreach(pairs(lines)) do (linenumber, rawline)
        codeline = stripcomment(rawline)
        isempty(strip(codeline)) && return

        declaration = parsefunctiondeclaration(codeline)
        isnothing(declaration) && return

        name = declaration.name
        basename = replace(name, "!" => "")
        if basename in typenames
            return
        end

        if occursin(r"[A-Z]", basename)
            suggestion = lowercase(basename) * (endswith(name, "!") ? "!" : "")
            push!(
                violations,
                RuleViolation(
                    :function_name_lowercase,
                    String(file),
                    name,
                    linenumber,
                    linenumber,
                    "function name `$name` must use lowercase squashed words",
                    "constructors are exempt; rename to lowercase, for example `$suggestion`",
                ),
            )
        end
    end

    return violations
end
