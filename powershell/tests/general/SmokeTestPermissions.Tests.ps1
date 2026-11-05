# The smoke test authenticates as an application, so its app registration needs an admin-consented
# application permission for every default scope. .github/workflows/maester-action-smoke-test.md is
# the setup list a maintainer works from, and nothing tied it to Get-MtGraphScope: a scope added to
# the default set did not reach the list, and the smoke test failed in the demo tenant with a 403
# that names a permission the list never asked for. When this fails, add the scope to the list.
Describe 'Smoke test application permissions' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

        $script:SetupDoc = Join-Path (Resolve-Path "$PSScriptRoot/../../..").Path '.github/workflows/maester-action-smoke-test.md'

        # The scopes the setup list asks for: the bullet items of the application-permission step,
        # each a single back-quoted scope on its own line.
        $script:DocumentedScopes = @(
            Get-Content -Path $script:SetupDoc |
                ForEach-Object { if ($_ -match '^\s*-\s+`([A-Za-z0-9.\-]+)`\s*$') { $Matches[1] } }
        )

        $script:DefaultScopes = @(Get-MtGraphScope)
    }

    It 'finds the application-permission list in the setup document' {
        $script:DocumentedScopes.Count | Should -BeGreaterThan 0 -Because 'the rest of this file compares against that list'
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
