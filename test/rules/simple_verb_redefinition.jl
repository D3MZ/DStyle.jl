@testset "check_simple_verb_redefinition" begin
    pass_source = """
    record!(history, s) = push!(history, State(s))
    recordself!(history, s) = recordself!(history, s)
    passthrough(history, s) = history

    function recordlong!(history, s)
        return push!(history, s)
    end
    """

    fail_source = """
    record!(history::History, s::State) = push!(history, s)
    store!(history, s) = Base.push!(history, s)
    pack(xs...) = collect(xs...)
    trimto(history; limit=1) = trim(history; limit=limit)
    timestamp() = time()
    """

    @test isempty(DStyle.check_simple_verb_redefinition(pass_source))

    violations = DStyle.check_simple_verb_redefinition(fail_source; file = "aliases.jl")
    @test length(violations) == 5
    @test all(v -> v.rule == :simple_verb_redefinition, violations)
    @test all(v -> v.file == "aliases.jl", violations)
    @test any(v -> v.function_name == "record!", violations)
    @test any(v -> occursin("call `push!` directly", v.hint), violations)
end

@testset "test_simple_verb_redefinition" begin
    mktempdir() do dir
        good_file = joinpath(dir, "good.jl")
        bad_file = joinpath(dir, "bad.jl")

        write(
            good_file,
            """
            keep(history, s) = push!(history, State(s))
            """,
        )

        write(
            bad_file,
            """
            record!(history, s) = push!(history, s)
            """,
        )

        @test isempty(DStyle.test_simple_verb_redefinition([good_file]))
        violations = DStyle.check_simple_verb_redefinition(read(bad_file, String); file = bad_file)
        @test length(violations) == 1
        @test only(violations).function_name == "record!"
    end
end
