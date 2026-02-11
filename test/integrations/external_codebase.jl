@testset "external codebase checks" begin
    mktempdir() do dir
        mkpath(joinpath(dir, "src"))
        mkpath(joinpath(dir, "extras"))

        good_file = joinpath(dir, "src", "good.jl")
        bad_file = joinpath(dir, "src", "bad.jl")
        ignored_file = joinpath(dir, "extras", "ignored.jl")

        write(
            good_file,
            """
            goodname(x) = x
            """,
        )

        write(
            bad_file,
            """
            BadName(x) = x
            """,
        )

        write(
            ignored_file,
            """
            AlsoBad(x) = x
            """,
        )

        discovered = codebasepaths(dir)
        @test good_file in discovered
        @test bad_file in discovered
        @test !(ignored_file in discovered)

        violations = test_codebase(
            dir;
            throw = false,
            julia_index_from_length = false,
            module_type_camel_case = false,
            mutating_function_bang = false,
            field_name_type_repetition = false,
            simple_verb_redefinition = false,
        )
        @test length(violations) == 1
        @test only(violations).rule == :function_name_lowercase

        warning_violations = @test_logs (:warn, r"DStyle found 1 style violation\(s\)") (:warn, r"function_name_lowercase") test_codebase(
            dir;
            throw = false,
            warn = true,
            julia_index_from_length = false,
            module_type_camel_case = false,
            mutating_function_bang = false,
            field_name_type_repetition = false,
            simple_verb_redefinition = false,
        )
        @test length(warning_violations) == 1

        fullscan = codebasepaths(dir; subdir = nothing)
        @test ignored_file in fullscan
    end
end

@testset "external codebase ignore list" begin
    mktempdir() do dir
        mkpath(joinpath(dir, "src"))
        file = joinpath(dir, "src", "external_constructor.jl")
        write(
            file,
            """
            function DataFrames.DataFrame(xs)
                push!(xs, 1)
                return xs
            end
            """,
        )

        flagged = test_codebase(
            dir;
            throw = false,
            julia_index_from_length = false,
            module_type_camel_case = false,
            field_name_type_repetition = false,
            simple_verb_redefinition = false,
        )
        @test length(flagged) == 2

        ignored = test_codebase(
            dir;
            throw = false,
            julia_index_from_length = false,
            module_type_camel_case = false,
            field_name_type_repetition = false,
            simple_verb_redefinition = false,
            ignore = ["DataFrame", "DataFrames.DataFrame"],
        )
        @test isempty(ignored)
    end
end
