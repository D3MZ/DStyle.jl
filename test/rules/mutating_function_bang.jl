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
    scale!(xs, μ) = (xs .*= μ; xs)
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

@testset "check_mutating_function_bang handles default Unicode args" begin
    source = "touch(xs, λ=1)=(push!(xs, λ); xs)"
    violations = DStyle.check_mutating_function_bang(source; file = "unicode-default.jl")
    @test length(violations) == 1
    @test only(violations).rule == :mutating_function_bang
end

@testset "constructors from other files are exempt for mutating bang check" begin
    mktempdir() do dir
        types_file = joinpath(dir, "types.jl")
        constructors_file = joinpath(dir, "constructors.jl")
        bad_file = joinpath(dir, "bad.jl")

        write(
            types_file,
            """
            abstract type Agent end

            struct Orders
                x
            end
            """,
        )

        write(
            constructors_file,
            """
            function Orders(a)
                a[1] = 1
                return a
            end

            function Agent(a)
                a[1] = 1
                return a
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

        @test isempty(DStyle.test_mutating_function_bang([types_file, constructors_file]))
        bad_source = read(bad_file, String)
        violations = DStyle.check_mutating_function_bang(
            bad_source;
            file = bad_file,
            constructor_names = ["Orders", "Agent"],
        )
        @test length(violations) == 1
        @test only(violations).function_name == "bump"
    end
end
