import TOML

"""
    github_actions_workflow(; name="DStyle", julia_version="1.11", paths=nothing, workflow_filename="dstyle.yml", package_url="https://github.com/D3MZ/DStyle.jl")

Returns a GitHub Actions workflow YAML string that runs `DStyle.test_all(...)`
on `push` and `pull_request`.
"""
function github_actions_workflow(;
    name::AbstractString = "DStyle",
    julia_version::AbstractString = "1.11",
    paths::Union{Nothing, AbstractVector{<:AbstractString}} = nothing,
    workflow_filename::AbstractString = "dstyle.yml",
    package_url::AbstractString = "https://github.com/D3MZ/DStyle.jl",
)
    testcall = isnothing(paths) ? "DStyle.test_all(throw=true)" :
               "DStyle.test_all(paths=$(juliaarrayliteral(paths)); throw=true)"

    return """
name: $name
on:
  push:
  pull_request:

jobs:
  dstyle:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
        with:
          version: '$julia_version'
      - name: Run DStyle checks
        run: |
          julia -e '
            using Pkg
            Pkg.add(url="$(quotejuliastring(package_url))")
            using DStyle
            $testcall
          '
"""
end

"""
    install_github_actions!(; workflow_path=".github/workflows/dstyle.yml", kwargs...)

Installs a generated DStyle workflow file into your repository and returns the
written path.
"""
function install_github_actions!(;
    workflow_path::AbstractString = joinpath(".github", "workflows", "dstyle.yml"),
    kwargs...,
)
    mkpath(dirname(workflow_path))
    write(workflow_path, github_actions_workflow(; kwargs...))
    return String(workflow_path)
end

"""
    install_test_dependency!(; project_path="Project.toml", package_name="DStyle", package_uuid="420f571e-3331-4aa3-9b68-c78ef2d7caab")

Ensures `Project.toml` includes DStyle as a test-only dependency by adding
`package_name => package_uuid` under `[extras]` and adding `package_name` to
`[targets].test`.
Returns `(project_path, added_to_extras, added_to_test_target)`.
"""
function install_test_dependency!(;
    project_path::AbstractString = "Project.toml",
    package_name::AbstractString = "DStyle",
    package_uuid::AbstractString = "420f571e-3331-4aa3-9b68-c78ef2d7caab",
)
    path = String(project_path)
    project = isfile(path) ? TOML.parsefile(path) : Dict{String, Any}()

    extras = get!(project, "extras", Dict{String, Any}())
    extras isa AbstractDict || throw(ArgumentError("[extras] must be a table in $path"))
    added_to_extras = !haskey(extras, String(package_name))
    extras[String(package_name)] = String(package_uuid)

    targets = get!(project, "targets", Dict{String, Any}())
    targets isa AbstractDict || throw(ArgumentError("[targets] must be a table in $path"))

    existing_test_target = get(targets, "test", String[])
    test_target_entries = if existing_test_target isa AbstractVector
        map(String, collect(existing_test_target))
    elseif existing_test_target isa AbstractString
        [String(existing_test_target)]
    else
        throw(ArgumentError("[targets].test must be an array of strings in $path"))
    end

    added_to_test_target = !(String(package_name) in test_target_entries)
    if added_to_test_target
        push!(test_target_entries, String(package_name))
    end
    targets["test"] = test_target_entries

    open(path, "w") do io
        TOML.print(io, project)
    end

    return (
        project_path = path,
        added_to_extras = added_to_extras,
        added_to_test_target = added_to_test_target,
    )
end

"""
    github_actions_badge(repo; workflow_filename="dstyle.yml", label="DStyle", branch=nothing)

Returns Markdown for a dynamic GitHub Actions badge for the provided repository
`owner/repo`.
"""
function github_actions_badge(
    repo::AbstractString;
    workflow_filename::AbstractString = "dstyle.yml",
    label::AbstractString = "DStyle",
    branch::Union{Nothing, AbstractString} = nothing,
)
    imageurl = "https://github.com/$(String(repo))/actions/workflows/$(String(workflow_filename))/badge.svg"
    if !isnothing(branch)
        imageurl *= "?branch=$(urlescape(String(branch)))"
    end
    workflowurl = "https://github.com/$(String(repo))/actions/workflows/$(String(workflow_filename))"
    return "[![$(String(label))]($imageurl)]($workflowurl)"
end

"""
    github_actions_badge(; repo=nothing, workflow_filename="dstyle.yml", label="DStyle", branch=nothing)

Like `github_actions_badge(repo; ...)`, but infers `repo` from
`ENV["GITHUB_REPOSITORY"]` or your local `git remote origin` when omitted.
"""
function github_actions_badge(;
    repo::Union{Nothing, AbstractString} = nothing,
    workflow_filename::AbstractString = "dstyle.yml",
    label::AbstractString = "DStyle",
    branch::Union{Nothing, AbstractString} = nothing,
)
    detectedrepo = isnothing(repo) ? infergithubrepo() : String(repo)
    if isnothing(detectedrepo)
        throw(ArgumentError("Could not infer GitHub repo. Pass repo=\"owner/repo\"."))
    end
    return github_actions_badge(
        something(detectedrepo);
        workflow_filename = workflow_filename,
        label = label,
        branch = branch,
    )
end

"""
    setup_github_actions_badge!(; workflow_path=".github/workflows/dstyle.yml", repo=nothing, branch=nothing, setup_test_dependency=true, project_path="Project.toml", kwargs...)

One-shot setup helper: writes the DStyle GitHub Actions workflow and returns
the dynamic badge markdown (with inferred repo unless explicitly provided).
When `setup_test_dependency=true`, also ensures DStyle is in `[extras]` and
`[targets].test` for `project_path`.
Returns a named tuple `(workflow_path, repo, badge, test_dependency)`.
"""
function setup_github_actions_badge!(;
    workflow_path::AbstractString = joinpath(".github", "workflows", "dstyle.yml"),
    repo::Union{Nothing, AbstractString} = nothing,
    branch::Union{Nothing, AbstractString} = nothing,
    setup_test_dependency::Bool = true,
    project_path::AbstractString = "Project.toml",
    kwargs...,
)
    written = install_github_actions!(workflow_path = workflow_path; kwargs...)
    test_dependency = setup_test_dependency ? install_test_dependency!(project_path = project_path) : nothing
    workflowfilename = basename(workflow_path)
    detectedrepo = isnothing(repo) ? infergithubrepo() : String(repo)
    if isnothing(detectedrepo)
        throw(ArgumentError("Workflow installed, but repo could not be inferred. Pass repo=\"owner/repo\"."))
    end
    badge = github_actions_badge(
        something(detectedrepo);
        workflow_filename = workflowfilename,
        branch = branch,
    )
    return (
        workflow_path = written,
        repo = something(detectedrepo),
        badge = badge,
        test_dependency = test_dependency,
    )
end

"""
    setupgithub!(; kwargs...)

One-call GitHub setup. Installs the DStyle GitHub Actions workflow and returns
`(workflow_path, repo, badge, test_dependency)` for immediate README usage.
"""
function setupgithub!(; kwargs...)
    return setup_github_actions_badge!(; kwargs...)
end

"""
    setup!(; kwargs...)

Backward-compatible alias for `setupgithub!()`.
"""
function setup!(; kwargs...)
    return setupgithub!(; kwargs...)
end
