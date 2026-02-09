@testset "check_field_name_type_repetition" begin
    pass_source = """
    struct OrderBook
        bids
        asks
    end

    struct Agent
        state
    end

    struct Broker
        quote
    end

    struct Environment
        step
    end

    get(a::Agent, b::Broker, e::Environment) = (a, b, e)
    """

    fail_source = """
    struct OrderBook
        orderbookbids
        orderbookasks
    end

    struct Agent
        state
    end

    struct Broker
        quote
    end

    struct Environment
        step
    end

    getstate(agent::Agent, broker::Broker, environment::Environment) = (agent, broker, environment)
    """

    @test isempty(DStyle.check_field_name_type_repetition(pass_source))

    violations = DStyle.check_field_name_type_repetition(fail_source; file = "repetition.jl")
    @test length(violations) == 3
    @test all(v -> v.rule == :field_name_type_repetition, violations)
    @test any(v -> occursin("field `orderbookbids` repeats", v.message), violations)

    function_violation = only(filter(v -> occursin("typed argument names repeat", v.message), violations))
    @test occursin("get(a::Agent, b::Broker, e::Environment)", function_violation.hint)
end

@testset "test_field_name_type_repetition" begin
    mktempdir() do dir
        good_file = joinpath(dir, "good.jl")
        bad_file = joinpath(dir, "bad.jl")

        write(
            good_file,
            """
            struct Agent
                state
            end

            get(a::Agent) = a
            """,
        )

        write(
            bad_file,
            """
            struct Agent
                agentstate
            end

            getstate(agent::Agent) = agent
            """,
        )

        @test isempty(DStyle.test_field_name_type_repetition([good_file]))
        @test !isempty(DStyle.check_field_name_type_repetition(read(bad_file, String); file = bad_file))
    end
end
