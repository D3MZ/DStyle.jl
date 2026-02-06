using DStyle
using Test

@testset "DStyle.jl" begin
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
    end

    @testset "test_all" begin
        mktempdir() do dir
            good_file = joinpath(dir, "good.jl")
            bad_file = joinpath(dir, "bad.jl")

            write(
                good_file,
                """
                function sumloop!(x)
                    for i = eachindex(x)
                        x[i] += 1
                    end
                end
                """,
            )

            write(
                bad_file,
                """
                function sumloop!(x)
                    y = x
                    for i = eachindex(y)
                        y[i] += 1
                    end
                end
                """,
            )

            violations = DStyle.test_all(paths = [good_file, bad_file], throw = false)
            @test length(violations) == 1
            @test violations[1].file == bad_file

            @test_throws ErrorException DStyle.test_all(paths = [good_file, bad_file], throw = true)
        end
    end
end
