@testset "GitHub Actions helpers" begin
    workflow = DStyle.github_actions_workflow(paths = ["src/MyPkg.jl"])
    @test occursin("name: DStyle", workflow)
    @test occursin("uses: julia-actions/setup-julia@v2", workflow)
    @test occursin("DStyle.test_all(paths=[\"src/MyPkg.jl\"]; throw=true)", workflow)

    default_workflow = DStyle.github_actions_workflow()
    @test occursin("DStyle.test_all(throw=true)", default_workflow)

    mktempdir() do dir
        workflow_path = joinpath(dir, ".github", "workflows", "dstyle.yml")
        written = DStyle.install_github_actions!(
            workflow_path = workflow_path,
            paths = ["src/MyPkg.jl", "src/other.jl"],
        )
        @test written == workflow_path
        @test isfile(workflow_path)

        contents = read(workflow_path, String)
        @test occursin("DStyle.test_all(paths=[\"src/MyPkg.jl\", \"src/other.jl\"]; throw=true)", contents)
    end

    badge = DStyle.github_actions_badge("octocat/hello-world")
    @test badge == "[![DStyle](https://github.com/octocat/hello-world/actions/workflows/dstyle.yml/badge.svg)](https://github.com/octocat/hello-world/actions/workflows/dstyle.yml)"

    branch_badge = DStyle.github_actions_badge(
        "octocat/hello-world";
        workflow_filename = "custom.yml",
        branch = "main",
    )
    @test occursin("/custom.yml/badge.svg?branch=main", branch_badge)

    withenv("GITHUB_REPOSITORY" => "octocat/env-repo") do
        env_badge = DStyle.github_actions_badge()
        @test occursin("octocat/env-repo/actions/workflows/dstyle.yml/badge.svg", env_badge)
    end

    mktempdir() do dir
        oldpwd = pwd()
        try
            cd(dir)
            run(`git init -q`)
            run(`git remote add origin git@github.com:octocat/hello-world.git`)

            withenv("GITHUB_REPOSITORY" => nothing) do
                result = DStyle.setup!(paths = ["src/MyPkg.jl"])
                @test result.workflow_path == joinpath(".github", "workflows", "dstyle.yml")
                @test result.repo == "octocat/hello-world"
                @test occursin("octocat/hello-world/actions/workflows/dstyle.yml/badge.svg", result.badge)
                @test isfile(joinpath(".github", "workflows", "dstyle.yml"))
            end
        finally
            cd(oldpwd)
        end
    end
end
