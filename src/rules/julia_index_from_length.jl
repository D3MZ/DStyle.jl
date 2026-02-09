"""
    check_index_from_length(source; file="<memory>")

Reports lines that index or iterate using bounds derived from `length`/`size`,
for example `for i in 1:length(x)` or `x[1:size(x, 1)]`.
"""
function check_index_from_length(
    source::AbstractString;
    file::AbstractString = "<memory>",
)
    lines = split(source, '\n')
    violations = RuleViolation[]

    infunction = false
    functionname = "<top-level>"
    functionline = 0
    depth = 0
    inmultilinestring = false

    foreach(pairs(lines)) do (linenumber, rawline)
        codeinput, inmultilinestring = stripdocstringline(rawline, inmultilinestring)
        codeline = stripcomment(codeinput)
        codeline = stripstringliterals(codeline)
        if isempty(strip(codeline))
            return
        end

        if !infunction
            name = functionnamefromdefinition(codeline)
            if !isnothing(name)
                infunction = true
                functionname = something(name)
                functionline = linenumber
                depth = blockdelta(codeline)
                return
            end
        end

        if lineusesindexfromlength(codeline)
            message = "indexing with indices obtained from length/size is discouraged (JuliaIndexFromLength)"
            hint = "use eachindex(array) or axes(array, dim) instead of 1:length(array)/1:size(array, dim)"
            push!(
                violations,
                RuleViolation(
                    :julia_index_from_length,
                    String(file),
                    functionname,
                    functionline,
                    linenumber,
                    message,
                    hint,
                ),
            )
        end

        if infunction
            depth += blockdelta(codeline)
            if depth <= 0
                infunction = false
                functionname = "<top-level>"
                functionline = 0
            end
        end
    end

    return violations
end
