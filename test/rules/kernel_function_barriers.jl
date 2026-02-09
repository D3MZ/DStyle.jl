@testset "check_kernel_function_barriers" begin
    pass_source = """
    function filltwos!(a)
        for i = eachindex(a)
            a[i] = 2
        end
    end

    function strangetwos(n)
        a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
        filltwos!(a)
        return a
    end
    """

    fail_source = """
    function strangetwos(n)
        a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
        for i = 1:n
            a[i] = 2
        end
        return a
    end
    """

    @test isempty(DStyle.check_kernel_function_barriers(pass_source))

    violations = DStyle.check_kernel_function_barriers(fail_source; file = "example.jl")
    @test length(violations) == 1
    @test violations[1].rule == :kernel_function_barrier
    @test violations[1].file == "example.jl"
    @test violations[1].function_name == "strangetwos"
    @test violations[1].function_line == 1
    @test violations[1].loop_line == 3
    @test occursin("first loop starts 2 lines after function signature (max: 1)", violations[1].message)
    @test occursin("extract the loop into a kernel helper function", violations[1].hint)
    @test occursin("example.jl:3: kernel_function_barrier:", string(violations[1]))
    @test occursin("Hint:", string(violations[1]))
end

@testset "test_kernel_function_barriers" begin
    mktempdir() do dir
        good_file = joinpath(dir, "good.jl")
        bad_file = joinpath(dir, "bad.jl")
        write(
            good_file,
            """
            function fastloop(x)
                for i = eachindex(x)
                    x[i] += 1
                end
                return x
            end
            """,
        )
        write(
            bad_file,
            """
            function slowloop(x)
                y = x
                for i = eachindex(y)
                    y[i] += 1
                end
                return y
            end
            """,
        )

        @test isempty(DStyle.test_kernel_function_barriers([good_file]))

        violations = DStyle.check_kernel_function_barriers(read(bad_file, String); file = bad_file)
        @test length(violations) == 1

        report = getfield(DStyle, :formatviolationreport)(violations)
        @test occursin("DStyle found 1 kernel function barrier violation(s)", report)
        @test occursin("L3 slowloop:", report)
    end
end
