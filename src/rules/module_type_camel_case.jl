"""
    check_module_type_camel_case(source; file="<memory>")

Checks that module and type declarations use `UpperCamelCase`.
"""
function check_module_type_camel_case(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    lines = split(source, '\n')
    violations = RuleViolation[]

    foreach(pairs(lines)) do (linenumber, rawline)
        codeline = stripcomment(rawline)
        isempty(strip(codeline)) && return

        modulematch = match(r"^\s*(?:module|baremodule)\s+([A-Za-z_]\w*)\b", codeline)
        if !isnothing(modulematch)
            name = String(modulematch.captures[1])
            if !uppercamelcase(name)
                push!(
                    violations,
                    RuleViolation(
                        :module_type_camel_case,
                        String(file),
                        name,
                        linenumber,
                        linenumber,
                        "module name `$name` must use UpperCamelCase",
                        "rename to UpperCamelCase, for example `MyModule`",
                    ),
                )
            end
            return
        end

        structmatch = match(r"^\s*(?:mutable\s+)?struct\s+([A-Za-z_]\w*)\b", codeline)
        if !isnothing(structmatch)
            name = String(structmatch.captures[1])
            if !uppercamelcase(name)
                push!(
                    violations,
                    RuleViolation(
                        :module_type_camel_case,
                        String(file),
                        name,
                        linenumber,
                        linenumber,
                        "type name `$name` must use UpperCamelCase",
                        "rename to UpperCamelCase, for example `MyType`",
                    ),
                )
            end
            return
        end

        abstractmatch = match(r"^\s*abstract\s+type\s+([A-Za-z_]\w*)\b", codeline)
        if !isnothing(abstractmatch)
            name = String(abstractmatch.captures[1])
            if !uppercamelcase(name)
                push!(
                    violations,
                    RuleViolation(
                        :module_type_camel_case,
                        String(file),
                        name,
                        linenumber,
                        linenumber,
                        "abstract type name `$name` must use UpperCamelCase",
                        "rename to UpperCamelCase, for example `AbstractThing`",
                    ),
                )
            end
            return
        end

        primitivematch = match(r"^\s*primitive\s+type\s+([A-Za-z_]\w*)\b", codeline)
        if !isnothing(primitivematch)
            name = String(primitivematch.captures[1])
            if !uppercamelcase(name)
                push!(
                    violations,
                    RuleViolation(
                        :module_type_camel_case,
                        String(file),
                        name,
                        linenumber,
                        linenumber,
                        "primitive type name `$name` must use UpperCamelCase",
                        "rename to UpperCamelCase, for example `MyBitsType`",
                    ),
                )
            end
            return
        end
    end

    return violations
end
