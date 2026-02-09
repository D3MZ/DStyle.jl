struct RuleViolation
    rule::Symbol
    file::String
    function_name::String
    function_line::Int
    loop_line::Int
    message::String
    hint::String
end

Base.show(io::IO, violation::RuleViolation) = print(
    io,
    "$(violation.file):$(violation.loop_line): $(violation.rule): $(violation.message). Hint: $(violation.hint)",
)
