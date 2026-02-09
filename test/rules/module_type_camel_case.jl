@testset "check_module_type_camel_case" begin
    pass_source = """
    module GoodModule

    struct GoodType
        x::Int
    end

    abstract type AbstractThing end
    primitive type TinyBits 8 end

    end
    """

    fail_source = """
    module bad_module

    struct bad_type
        x::Int
    end

    abstract type abstract_thing end
    primitive type tiny_bits 8 end

    end
    """

    @test isempty(DStyle.check_module_type_camel_case(pass_source))

    violations = DStyle.check_module_type_camel_case(fail_source; file = "naming.jl")
    @test length(violations) == 4
    @test all(v -> v.rule == :module_type_camel_case, violations)
    @test all(v -> v.file == "naming.jl", violations)
    @test occursin("UpperCamelCase", violations[1].message)
end

@testset "test_module_type_camel_case" begin
    mktempdir() do dir
        good_file = joinpath(dir, "good.jl")
        bad_file = joinpath(dir, "bad.jl")

        write(
            good_file,
            """
            module GoodModule
            struct FineType
                x::Int
            end
            end
            """,
        )

        write(
            bad_file,
            """
            module bad_module
            struct bad_type
                x::Int
            end
            end
            """,
        )

        @test isempty(DStyle.test_module_type_camel_case([good_file]))
        @test !isempty(DStyle.check_module_type_camel_case(read(bad_file, String); file = bad_file))
    end
end
