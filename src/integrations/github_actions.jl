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
    setup_github_actions_badge!(; workflow_path=".github/workflows/dstyle.yml", repo=nothing, branch=nothing, kwargs...)

One-shot setup helper: writes the DStyle GitHub Actions workflow and returns
the dynamic badge markdown (with inferred repo unless explicitly provided).
Returns a named tuple `(workflow_path, repo, badge)`.
"""
function setup_github_actions_badge!(;
    workflow_path::AbstractString = joinpath(".github", "workflows", "dstyle.yml"),
    repo::Union{Nothing, AbstractString} = nothing,
    branch::Union{Nothing, AbstractString} = nothing,
    kwargs...,
)
    written = install_github_actions!(workflow_path = workflow_path; kwargs...)
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
    return (workflow_path = written, repo = something(detectedrepo), badge = badge)
end

"""
    setupgithub!(; kwargs...)

One-call GitHub setup. Installs the DStyle GitHub Actions workflow and returns
`(workflow_path, repo, badge)` for immediate README usage.
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
