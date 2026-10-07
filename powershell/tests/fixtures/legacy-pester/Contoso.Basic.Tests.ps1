[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares the variable between blocks.')] param() # Legacy Pester fixture: plain Describe/It with "ID: Title" names, tags with spaces, Should assertions.
# Data is inline, so the file runs without a tenant.
Describe "Contoso Baseline" -Tag "Contoso", "Contoso Baseline", "Entra ID P1" {
    BeforeAll {
        $policies = @(
            [pscustomobject]@{ displayName = 'Require MFA for admins'; state = 'enabled'; grantControls = @('mfa') }
            [pscustomobject]@{ displayName = 'Block legacy auth'; state = 'enabledForReportingButNotEnforced'; grantControls = @('block') }
        )
    }

    It "CONTOSO.1001: At least one Conditional Access policy requires MFA" -Tag "CONTOSO.1001", "Severity:High" {
        ($policies | Where-Object { $_.state -eq 'enabled' -and $_.grantControls -contains 'mfa' }) | Should -Not -BeNullOrEmpty
    }

    It "CONTOSO.1002: Legacy authentication is blocked by an enabled policy" -Tag "CONTOSO.1002" {
        $blocking = $policies | Where-Object { $_.state -eq 'enabled' -and $_.grantControls -contains 'block' }
        $blocking | Should -Not -BeNullOrEmpty -Because "an enabled policy should block legacy authentication"
    }

    It "CONTOSO.1003: Policy names are not empty. See https://contoso.example/docs/CONTOSO.1003" -Tag "CONTOSO.1003" {
        $policies.displayName | ForEach-Object { $_ | Should -Not -BeNullOrEmpty }
    }

    It "CONTOSO.1004: Long running inventory check" -Tag "CONTOSO.1004", "LongRunning" {
        $policies.Count | Should -BeGreaterThan 0
    }

    # 2.x maps five exception types to Error and every other exception to Failed. Pester
    # rows keep that rule in 3.0 (design 5.3 item 1).
    It "CONTOSO.1005: Body throws a RuntimeException" -Tag "CONTOSO.1005" {
        throw "Contoso API returned an unexpected payload"
    }

    It "CONTOSO.1006: Body throws a FileNotFoundException" -Tag "CONTOSO.1006" {
        throw [System.IO.FileNotFoundException]::new("Contoso export file is missing")
    }
}
