module DStyle

using Test

export RuleViolation,
    check_field_name_type_repetition,
    check_function_name_lowercase,
    check_index_from_length,
    check_kernel_function_barriers,
    check_module_type_camel_case,
    check_mutating_function_bang,
    github_actions_badge,
    github_actions_workflow,
    install_github_actions!,
    test_field_name_type_repetition,
    test_function_name_lowercase,
    test_index_from_length,
    test_kernel_function_barriers,
    test_module_type_camel_case,
    test_mutating_function_bang,
    setupgithub!,
    setup!,
    setup_github_actions_badge!,
    readme_badge,
    test_all

include("core/types.jl")
include("core/scanner.jl")
include("rules/kernel_function_barrier.jl")
include("rules/julia_index_from_length.jl")
include("rules/module_type_camel_case.jl")
include("rules/function_name_lowercase.jl")
include("rules/mutating_function_bang.jl")
include("rules/field_name_type_repetition.jl")
include("core/reporting.jl")
include("core/paths.jl")
include("core/strings.jl")
include("core/runner.jl")
include("integrations/github_actions.jl")

end
