@testset "check_function_name_lowercase" begin
    pass_source = """
    struct OrderState
        x::Int
    end

    function orderstate(x)
        return x
    end

    function OrderState(x)
        return OrderState(x)
    end

    load_table(x) = x
    runmean(μ, x) = (μ + x) / 2
    """

    fail_source = """
    function HasKeySafe(dict, key)
        return haskey(dict, key)
    end

    DoThing(x) = x
    """

    @test isempty(DStyle.check_function_name_lowercase(pass_source))

    violations = DStyle.check_function_name_lowercase(fail_source; file = "functions.jl")
    @test length(violations) == 2
    @test all(v -> v.rule == :function_name_lowercase, violations)
    @test all(v -> v.file == "functions.jl", violations)
    @test occursin("constructors are exempt", violations[1].hint)
end

@testset "test_function_name_lowercase" begin
    mktempdir() do dir
        good_file = joinpath(dir, "good.jl")
        bad_file = joinpath(dir, "bad.jl")

        write(
            good_file,
            """
            struct BuildType
                x::Int
            end

            function BuildType(x)
                return x
            end

            makesafe(x) = x
            """,
        )

        write(
            bad_file,
            """
            RunFast(x) = x
            """,
        )

        @test isempty(DStyle.test_function_name_lowercase([good_file]))
        @test !isempty(DStyle.check_function_name_lowercase(read(bad_file, String); file = bad_file))
    end
end
