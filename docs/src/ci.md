```@meta
CurrentModule = DStyle
```

# CI and Badge Integration

DStyle ships helper functions to install a GitHub workflow and generate badges.

## Generate a local README badge

```julia
using DStyle

badge = DStyle.readme_badge(
    paths = ["src/YourPackageName.jl"],
    link = "https://github.com/you/YourPackageName/actions",
)
println(badge)
```

If checks pass, the badge message is `pass`.
If checks fail, the badge message is `fail(N)`.

## Generate workflow YAML without writing files

```julia
using DStyle

yaml = DStyle.github_actions_workflow(
    julia_version = "1.12",
    paths = ["src/YourPackageName.jl"],
)
println(yaml)
```

## Install workflow file in current repository

```julia
using DStyle

workflow_path = DStyle.install_github_actions!()
println(workflow_path)
# .github/workflows/dstyle.yml
```

## Generate a dynamic GitHub Actions badge

```julia
using DStyle

badge = DStyle.github_actions_badge("your-org/your-repo"; branch = "main")
println(badge)
```

## One-shot setup

`setupgithub!()` writes the workflow and returns a badge in one call:

```julia
using DStyle

setup = DStyle.setupgithub!()
println(setup.workflow_path)
println(setup.repo)
println(setup.badge)
```

`setup!()` is a backward-compatible alias.
