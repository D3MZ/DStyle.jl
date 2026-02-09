module DStyle

using Test

export RuleViolation,
    check_index_from_length,
    check_kernel_function_barriers,
    github_actions_badge,
    github_actions_workflow,
    install_github_actions!,
    test_index_from_length,
    test_kernel_function_barriers,
    setupgithub!,
    setup!,
    setup_github_actions_badge!,
    readme_badge,
    test_all

include("core/types.jl")
include("core/scanner.jl")
include("rules/kernel_function_barrier.jl")
include("rules/julia_index_from_length.jl")
include("core/reporting.jl")
include("core/paths.jl")
include("core/strings.jl")
include("core/runner.jl")
include("integrations/github_actions.jl")

end
