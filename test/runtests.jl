using DStyle
using Test

@testset "DStyle.jl" begin
    @testset "check_kernel_function_barriers" begin
        pass_source = """
        function filltwos!(a)
            for i = eachindex(a)
                a[i] = 2
            end
        end

        function strangetwos(n)
            a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
            filltwos!(a)
            return a
        end
        """

        fail_source = """
        function strangetwos(n)
            a = Vector{rand(Bool) ? Int64 : Float64}(undef, n)
            for i = 1:n
                a[i] = 2
            end
            return a
        end
        """

        @test isempty(DStyle.check_kernel_function_barriers(pass_source))

        violations = DStyle.check_kernel_function_barriers(fail_source; file = "example.jl")
        @test length(violations) == 1
        @test violations[1].rule == :kernel_function_barrier
        @test violations[1].file == "example.jl"
        @test violations[1].function_name == "strangetwos"
        @test violations[1].function_line == 1
        @test violations[1].loop_line == 3
    end

    @testset "test_all" begin
        mktempdir() do dir
            good_file = joinpath(dir, "good.jl")
            bad_file = joinpath(dir, "bad.jl")

            write(
                good_file,
                """
                function sumloop!(x)
                    for i = eachindex(x)
                        x[i] += 1
                    end
                end
                """,
            )

            write(
                bad_file,
                """
                function sumloop!(x)
                    y = x
                    for i = eachindex(y)
                        y[i] += 1
                    end
                end
                """,
            )

            violations = DStyle.test_all(paths = [good_file, bad_file], throw = false)
            @test length(violations) == 1
            @test violations[1].file == bad_file

            @test_throws ErrorException DStyle.test_all(paths = [good_file, bad_file], throw = true)
        end
    end

    @testset "test_all module API" begin
        # Aqua-style call form
        @test isempty(DStyle.test_all(DStyle; throw = false, max_lines_from_signature = 1000))

        # Modules without a resolvable package path should ask for explicit paths.
        @test_throws ArgumentError DStyle.test_all(Main; throw = false)
    end

    @testset "readme_badge" begin
        mktempdir() do dir
            good_file = joinpath(dir, "good.jl")
            bad_file = joinpath(dir, "bad.jl")

            write(
                good_file,
                """
                function filltwos!(a)
                    for i = eachindex(a)
                        a[i] = 2
                    end
                end
                """,
            )

            write(
                bad_file,
                """
                function filltwos!(a)
                    x = a
                    for i = eachindex(x)
                        x[i] = 2
                    end
                end
                """,
            )

            pass_badge = DStyle.readme_badge(paths = [good_file])
            @test occursin("img.shields.io/badge", pass_badge)
            @test occursin("-pass-brightgreen", pass_badge)

            fail_badge = DStyle.readme_badge(paths = [bad_file])
            @test occursin("-fail%281%29-red", fail_badge)

            linked_badge = DStyle.readme_badge(paths = [good_file], link = "https://example.com")
            @test startswith(linked_badge, "[![DStyle status](")
            @test endswith(linked_badge, "](https://example.com)")
        end
    end

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

        mktempdir() do dir
            oldpwd = pwd()
            oldrepo = get(ENV, "GITHUB_REPOSITORY", nothing)
            try
                cd(dir)
                run(`git init -q`)
                run(`git remote add origin git@github.com:octocat/hello-world.git`)

                result = DStyle.setup!(paths = ["src/MyPkg.jl"])
                @test result.workflow_path == joinpath(".github", "workflows", "dstyle.yml")
                @test result.repo == "octocat/hello-world"
                @test occursin("octocat/hello-world/actions/workflows/dstyle.yml/badge.svg", result.badge)
                @test isfile(joinpath(".github", "workflows", "dstyle.yml"))
            finally
                cd(oldpwd)
                if isnothing(oldrepo)
                    delete!(ENV, "GITHUB_REPOSITORY")
                else
                    ENV["GITHUB_REPOSITORY"] = oldrepo
                end
            end
        end
    end
end
