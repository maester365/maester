# The smoke test authenticates as an application, so its app registration needs an admin-consented
# application permission for every default scope. .github/workflows/maester-action-smoke-test.md is
# the setup list a maintainer works from, and nothing tied it to Get-MtGraphScope: a scope added to
# the default set did not reach the list, and the smoke test failed in the demo tenant with a 403
# that names a permission the list never asked for. When this fails, add the scope to the list.
Describe 'Smoke test application permissions' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

        $script:SetupDoc = Join-Path (Resolve-Path "$PSScriptRoot/../../..").Path '.github/workflows/maester-action-smoke-test.md'

        # The bullet items of the application-permission step, and only that step: it opens with the
        # sentence naming Get-MtGraphScope and ends where the next numbered step begins. Reading the
        # whole document instead would count a back-quoted bullet anywhere in it as a scope.
        $lines = @(Get-Content -Path $script:SetupDoc)
        $script:StepStart = -1
        $stepEnd = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($script:StepStart -lt 0) {
                if ($lines[$i] -match 'default read-only scopes returned by') { $script:StepStart = $i }
            } elseif ($lines[$i] -match '^\s*\d+\.\s') {
                $stepEnd = $i - 1
                break
            }
        }
        if ($stepEnd -lt 0) { $stepEnd = $lines.Count - 1 }

        $script:ScopeShape = '^\s*-\s+`([A-Za-z0-9.\-]+)`\s*$'
        $script:StepBullets = @()
        if ($script:StepStart -ge 0) {
            $script:StepBullets = @($lines[$script:StepStart..$stepEnd] | Where-Object { $_ -match '^\s*-\s' })
        }

        # The scopes the setup list asks for: each a single back-quoted scope on its own line.
        $script:DocumentedScopes = @(
            $script:StepBullets | ForEach-Object { if ($_ -match $script:ScopeShape) { $Matches[1] } }
        )

        $script:DefaultScopes = @(Get-MtGraphScope)
    }

    It 'finds the application-permission list in the setup document' {
        $script:StepStart | Should -BeGreaterOrEqual 0 -Because 'the rest of this file compares against that step'
        $script:DocumentedScopes.Count | Should -BeGreaterThan 0 -Because 'the rest of this file compares against that list'
    }

    It 'reads every bullet of the application-permission step as a scope' {
        $unreadable = @($script:StepBullets | Where-Object { $_ -notmatch $script:ScopeShape })
        $unreadable | Should -BeNullOrEmpty -Because (
            "a bullet this test cannot read is a permission it cannot compare, so it would be " +
            "granted and admin-consented without ever being checked against Get-MtGraphScope: " +
            "write each one as a single back-quoted scope on its own line, or update this test " +
            "with the new shape. Unreadable: $($unreadable -join ' | ')")
    }

    It 'documents every default scope' {
        $missing = @($script:DefaultScopes | Where-Object { $_ -notin $script:DocumentedScopes } | Sort-Object)
        $missing | Should -BeNullOrEmpty -Because (
            "the smoke-test app registration is consented from this list, so a default scope it omits " +
            "fails the smoke test with a 403: add $($missing -join ', ') to the application-permission " +
            "step of .github/workflows/maester-action-smoke-test.md")
    }

    It 'documents no scope that is not a default scope' {
        $extra = @($script:DocumentedScopes | Where-Object { $_ -notin $script:DefaultScopes } | Sort-Object)
        $extra | Should -BeNullOrEmpty -Because (
            "the list says it is the default read-only scopes, so a scope that Get-MtGraphScope does " +
            "not return asks for a permission Maester does not use: remove $($extra -join ', ')")
    }

    It 'lists the scopes in alphabetical order' {
        $script:DocumentedScopes | Should -Be @($script:DocumentedScopes | Sort-Object)
    }
}
