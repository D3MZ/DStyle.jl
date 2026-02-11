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

@testset "test_all module API" begin
    @test isnothing(DStyle.test_all(DStyle))

    @test isnothing(
        DStyle.test_all(
            DStyle;
            kernel_function_barriers = (max_lines_from_signature = 1000,),
        ),
    )

    @test isnothing(
        DStyle.test_all(
            Main;
            kernel_function_barriers = false,
            julia_index_from_length = false,
            module_type_camel_case = false,
            function_name_lowercase = false,
            mutating_function_bang = false,
            field_name_type_repetition = false,
            simple_verb_redefinition = false,
        ),
    )
end

@testset "test_all warn mode" begin
    mktempdir() do dir
        bad_file = joinpath(dir, "bad.jl")
        write(
            bad_file,
            """
            RunFast(x) = x
            """,
        )

        violations = @test_logs (:warn, r"DStyle found 1 style violation\(s\)") (:warn, r"function_name_lowercase") DStyle.test_all(
            paths = [bad_file],
            julia_index_from_length = false,
            module_type_camel_case = false,
            mutating_function_bang = false,
            field_name_type_repetition = false,
            simple_verb_redefinition = false,
            warn = true,
            throw = false,
        )
        @test length(violations) == 1
        @test only(violations).rule == :function_name_lowercase
    end
end
