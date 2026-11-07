# The step catalogue of the defender's path (docs/proposals/defenders-path.md, sections 4 and 14) and the steps that
# the built-in tests and the packs that ship with Maester name. The catalog build fails on the same problems
# (Get-MtStepProblem); the rules themselves are tested on fixtures in functions/engine/StepCatalog.Tests.ps1.

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:folder = Join-Path $script:repoRoot 'powershell/assets/steps'

    $files = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -File -Filter 'Test.*.ps1' |
            Where-Object { $_.FullName -notmatch '[\\/]custom[\\/]' })
    $script:tests = @(InModuleScope Maester -Parameters @{ Files = $files.FullName } {
            foreach ($file in $Files) { [pscustomobject](Read-MtNativeTest -Path $file -BuiltIn) }
        })
    $script:catalog = InModuleScope Maester { Get-MtStepCatalog }
}

Describe 'The step catalogue' {
    It 'Has steps and goals' {
        $script:catalog.Steps.Count | Should -BeGreaterThan 0
        $script:catalog.Goals.Count | Should -BeGreaterThan 0
    }

    It 'Has no problems, and every step a built-in test or pack names is in it' {
        $problems = @(InModuleScope Maester -Parameters @{ Tests = $script:tests; PackRoot = (Join-Path $script:repoRoot 'packs') } {
                Get-MtStepProblem -Test $Tests -PackRoot $PackRoot -Coverage
            })
        $problems | Should -BeNullOrEmpty
    }

    It 'Matches its JSON schema: <_>' -ForEach @(
        Get-ChildItem -Path (Join-Path (Resolve-Path "$PSScriptRoot/../../..").Path 'powershell/assets/steps') -Filter '*.json' |
            Where-Object Name -NE 'steps.schema.json' | ForEach-Object Name
    ) {
        $json = Get-Content -LiteralPath (Join-Path $script:folder $_) -Raw
        Test-Json -Json $json -SchemaFile (Join-Path $script:folder 'steps.schema.json') -ErrorAction SilentlyContinue | Should -BeTrue
    }

    It 'Is valid JSON Schema itself and rejects a step with an unknown key' {
        $bad = '{ "Product": "entra", "Steps": [ { "Id": "entra.x", "Title": "X", "Summary": "S.", "Sources": [ { "Url": "https://learn.microsoft.com/entra/x", "Note": "N.", "Reviewed": "2026-11-05" } ], "Severity": "High" } ] }'
        Test-Json -Json $bad -SchemaFile (Join-Path $script:folder 'steps.schema.json') -ErrorAction SilentlyContinue | Should -BeFalse
    }

    It 'Has goals whose steps are the goal step and its prerequisites, prerequisites first' {
        foreach ($goal in $script:catalog.Goals) {
            $goal.Steps[-1] | Should -Be $goal.Step -Because $goal.Id
            for ($i = 0; $i -lt $goal.Steps.Count; $i++) {
                $step = $script:catalog.Steps[$goal.Steps[$i]]
                $before = @($goal.Steps | Select-Object -First $i)
                foreach ($prerequisite in @($step.Requires) + @($step.RecommendedFirst) + @($step.RequiresOneOf | ForEach-Object { $_ })) {
                    $before | Should -Contain $prerequisite -Because "$($step.Id) depends on $prerequisite in the goal $($goal.Id)"
                }
            }
        }
    }
}
