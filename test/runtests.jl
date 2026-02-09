using DStyle
using Test

@testset "DStyle.jl" begin
    include("core/test_all.jl")
    include("rules/kernel_function_barriers.jl")
    include("rules/index_from_length.jl")
    include("rules/module_type_camel_case.jl")
    include("rules/function_name_lowercase.jl")
    include("rules/mutating_function_bang.jl")
    include("rules/field_name_type_repetition.jl")
    include("integrations/github_actions.jl")
    include("integrations/test_dependency.jl")
    include("integrations/readme_badge.jl")
end
