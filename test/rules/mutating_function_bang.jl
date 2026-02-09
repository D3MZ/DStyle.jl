@testset "check_mutating_function_bang" begin
    pass_source = """
    function normalize!(xs)
        xs .= xs ./ sum(xs)
        return xs
    end

    function score(xs)
        return sum(xs)
    end

    touch!(xs) = (push!(xs, 1); xs)
    """

    fail_source = """
    function normalize(xs)
        xs .= xs ./ sum(xs)
        return xs
    end

    touch(xs) = (push!(xs, 1); xs)
    """

    @test isempty(DStyle.check_mutating_function_bang(pass_source))

    violations = DStyle.check_mutating_function_bang(fail_source; file = "mutating.jl")
    @test length(violations) == 2
    @test all(v -> v.rule == :mutating_function_bang, violations)
    @test occursin("does not end with `!`", violations[1].message)
end

@testset "test_mutating_function_bang" begin
    mktempdir() do dir
        good_file = joinpath(dir, "good.jl")
        bad_file = joinpath(dir, "bad.jl")

        write(
            good_file,
            """
            function bump!(xs)
                xs[1] += 1
                return xs
            end
            """,
        )

        write(
            bad_file,
            """
            function bump(xs)
                xs[1] += 1
                return xs
            end
            """,
        )

        @test isempty(DStyle.test_mutating_function_bang([good_file]))
        @test !isempty(DStyle.check_mutating_function_bang(read(bad_file, String); file = bad_file))
    end
end
