---
name: cross-codebase-style-validation
description: Run DStyle checks before and after feature work across configured codebases, confirm findings are real regressions, and triage false positives versus edge cases.
---

# Cross-Codebase Style Validation

Use this skill when a task changes DStyle rules, scanner logic, or `test_all` behavior.

## Inputs

- Primary repo: current workspace (DStyle)
- External codebases: from `DSTYLE_EXTERNAL_CODEBASES` (comma-separated absolute paths)

## Workflow

1. Run baseline checks before code changes.
2. Implement feature/refactor.
3. Run the same checks after changes.
4. Compare deltas and triage new findings.

## Commands

Run package tests in DStyle:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

Run DStyle against configured external codebases:

```bash
julia --project -e '
using DStyle
using Test

paths = String[]
if haskey(ENV, "DSTYLE_EXTERNAL_CODEBASES")
    append!(paths, filter(!isempty, strip.(split(ENV["DSTYLE_EXTERNAL_CODEBASES"], ","))))
end

for root in paths
    @testset "External codebase: $root" begin
        violations = DStyle.test_codebase(root; throw=false, ignore=["DataFrame", "DataFrames.DataFrame"])
        @test violations isa Vector{DStyle.RuleViolation}
        println("$root -> ", length(violations), " violation(s)")
    end
end
'
```

## Triage Rules

When a test flags something:

1. Confirm reproducibility on unchanged input.
2. Check if the finding is a true style regression.
3. If it is a known integration edge case (for example external constructors like `DataFrames.DataFrame`), prefer `ignore` configuration.
4. If it is a parser/rule bug, add or update a test in `test/runtests.jl`-included suites before changing rule behavior.
5. Re-run all baseline commands after the fix.

## Output Expectations

Report:

- Which codebases were tested
- Before/after violation counts
- Which findings were true positives
- Which findings were ignored as edge cases and why
