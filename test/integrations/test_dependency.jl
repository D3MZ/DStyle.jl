using TOML

@testset "install_test_dependency!" begin
    mktempdir() do dir
        project_path = joinpath(dir, "Project.toml")
        write(
            project_path,
            """
            name = "ExamplePkg"
            uuid = "11111111-2222-3333-4444-555555555555"
            version = "0.1.0"

            [extras]
            Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

            [targets]
            test = ["Test"]
            """,
        )

        first_result = DStyle.install_test_dependency!(project_path = project_path)
        @test first_result.project_path == project_path
        @test first_result.added_to_extras
        @test first_result.added_to_test_target

        project = TOML.parsefile(project_path)
        @test project["extras"]["DStyle"] == "420f571e-3331-4aa3-9b68-c78ef2d7caab"
        @test "DStyle" in project["targets"]["test"]
        @test "Test" in project["targets"]["test"]

        second_result = DStyle.install_test_dependency!(project_path = project_path)
        @test !second_result.added_to_extras
        @test !second_result.added_to_test_target
    end
end
