"""
    check_module_type_camel_case(source; file="<memory>")

Checks that module and type declarations use `UpperCamelCase`.
"""
function check_module_type_camel_case(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    violations = RuleViolation[]
    tree = parsesourcetree(source)
    isnothing(tree) && return violations

    collectmoduletypecamelcaseviolations!(tree, violations, String(file), 1)
    return violations
end

function collectmoduletypecamelcaseviolations!(node, violations, file::String, line::Int)
    currentline = line

    if node isa LineNumberNode
        return sourceline(node)
    end

    if node isa Expr
        if node.head == :module && length(node.args) >= 2
            name = extracttypename(node.args[2])
            isnothing(name) && return currentline
            if !uppercamelcase(name)
                push!(
                    violations,
                    RuleViolation(
                        :module_type_camel_case,
                        file,
                        String(name),
                        currentline,
                        currentline,
                        "module name `$name` must use UpperCamelCase",
                        "rename to UpperCamelCase, for example `MyModule`",
                    ),
                )
            end
        elseif node.head == :struct && length(node.args) >= 2
            name = extracttypename(node.args[2])
            isnothing(name) && return currentline
            if !uppercamelcase(name)
                push!(
                    violations,
                    RuleViolation(
                        :module_type_camel_case,
                        file,
                        String(name),
                        currentline,
                        currentline,
                        "type name `$name` must use UpperCamelCase",
                        "rename to UpperCamelCase, for example `MyType`",
                    ),
                )
            end
        elseif node.head == :abstract && !isempty(node.args)
            name = extracttypename(node.args[1])
            isnothing(name) && return currentline
            if !uppercamelcase(name)
                push!(
                    violations,
                    RuleViolation(
                        :module_type_camel_case,
                        file,
                        String(name),
                        currentline,
                        currentline,
                        "abstract type name `$name` must use UpperCamelCase",
                        "rename to UpperCamelCase, for example `AbstractThing`",
                    ),
                )
            end
        elseif node.head == :primitive && !isempty(node.args)
            name = extracttypename(node.args[1])
            isnothing(name) && return currentline
            if !uppercamelcase(name)
                push!(
                    violations,
                    RuleViolation(
                        :module_type_camel_case,
                        file,
                        String(name),
                        currentline,
                        currentline,
                        "primitive type name `$name` must use UpperCamelCase",
                        "rename to UpperCamelCase, for example `MyBitsType`",
                    ),
                )
            end
        end

        foreach(node.args) do arg
            currentline = collectmoduletypecamelcaseviolations!(arg, violations, file, currentline)
        end
        return currentline
    end

    if node isa QuoteNode && node.value isa Expr
        return collectmoduletypecamelcaseviolations!(node.value, violations, file, currentline)
    end

    return currentline
end
