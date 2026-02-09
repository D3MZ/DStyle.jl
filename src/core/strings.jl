function quotejuliastring(value::AbstractString)
    text = String(value)
    text = replace(text, "\\" => "\\\\")
    text = replace(text, "\"" => "\\\"")
    return text
end

function juliaarrayliteral(paths::AbstractVector{<:AbstractString})
    escaped = ["\"$(quotejuliastring(path))\"" for path in paths]
    return "[" * join(escaped, ", ") * "]"
end

function urlescape(value::AbstractString)
    encoded = String(value)
    encoded = replace(encoded, "%" => "%25")
    encoded = replace(encoded, " " => "%20")
    encoded = replace(encoded, "(" => "%28", ")" => "%29")
    return encoded
end

function shieldescape(value::AbstractString)
    escaped = replace(String(value), "-" => "--", "_" => "__")
    return urlescape(escaped)
end
