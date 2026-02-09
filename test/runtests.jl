using DStyle
using Test

@testset "DStyle.jl" begin
    include("core/test_all.jl")
    include("rules/kernel_function_barriers.jl")
    include("rules/index_from_length.jl")
    include("integrations/readme_badge.jl")
end
