@testset "check_index_from_length" begin
    pass_source = """
    function stableindexing(xs, ys)
        for i in eachindex(xs)
            ys[i] = xs[i]
        end
        return ys
    end

    function stableaxes(A)
        for i in axes(A, 1)
            A[i, 1] = 0
        end
        return A
    end
    """

    fail_source = """
    function unstableindexing(xs)
        for i in 1:length(xs)
            xs[i] += 1
        end
        xs[length(xs)] = 0
        return xs
    end

    function unstableaxes(A)
        for i in 1:size(A, 1)
            A[i, 1] = 0
        end
        return A
    end
    """

    @test isempty(DStyle.check_index_from_length(pass_source))

    violations = DStyle.check_index_from_length(fail_source; file = "indexing.jl")
    @test length(violations) == 3
    @test all(v -> v.rule == :julia_index_from_length, violations)
    @test all(v -> v.file == "indexing.jl", violations)
    @test occursin("JuliaIndexFromLength", violations[1].message)
    @test occursin("use eachindex(array) or axes(array, dim)", violations[1].hint)
end

@testset "test_index_from_length" begin
    mktempdir() do dir
        good_file = joinpath(dir, "good.jl")
        bad_file = joinpath(dir, "bad.jl")
        write(
            good_file,
            """
            function ok(xs)
                for i in eachindex(xs)
                    xs[i] += 1
                end
                return xs
            end
            """,
        )
        write(
            bad_file,
            """
            function bad(xs)
                for i in 1:length(xs)
                    xs[i] += 1
                end
                return xs
            end
            """,
        )

        @test isempty(DStyle.test_index_from_length([good_file]))

        violations = DStyle.check_index_from_length(read(bad_file, String); file = bad_file)
        @test length(violations) == 1
        report = getfield(DStyle, :formatviolationreport)(violations)
        @test occursin("DStyle found 1 JuliaIndexFromLength violation(s)", report)
        @test occursin("L2 bad:", report)
    end
end
