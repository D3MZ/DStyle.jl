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
