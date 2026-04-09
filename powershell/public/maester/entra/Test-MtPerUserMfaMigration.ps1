function Test-MtPerUserMfaMigration {
    <#
    .SYNOPSIS
    Checks if the tenant has completed the migration from legacy per-user MFA to authentication methods policy.

    .DESCRIPTION
    The legacy per-user MFA and self-service password reset (SSPR) policies are deprecated.
    All authentication methods should be managed through the unified authentication methods policy.
    This test checks if the policyMigrationState is set to migrationComplete.

    .EXAMPLE
    Test-MtPerUserMfaMigration

    Returns true if the tenant has completed the migration to authentication methods policy.

    .LINK
    https://maester.dev/docs/commands/Test-MtPerUserMfaMigration
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion v1.0

        $migrationState = $result.policyMigrationState

        # A null/empty value indicates a new tenant that never had legacy settings, which is acceptable.
        $testResult = $migrationState -eq "migrationComplete" -or [string]::IsNullOrEmpty($migrationState)

        if ($testResult) {
            $currentState = if ([string]::IsNullOrEmpty($migrationState)) { "Not applicable (new tenant)" } else { $migrationState }
            $testResultMarkdown = "Well done. Your tenant has completed the migration from legacy per-user MFA to the authentication methods policy."
        } else {
            $currentState = $migrationState
            $testResultMarkdown = "Your tenant has not completed the migration from legacy per-user MFA to the authentication methods policy."
        }

        $status = if ($testResult) { "✅" } else { "❌" }

        $testResultMarkdown += "`n`n"
        $testResultMarkdown += "| Setting | Value | Status |`n"
        $testResultMarkdown += "|---------|-------|--------|`n"
        $testResultMarkdown += "| [Policy migration state](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods) | $currentState | $status |`n"

        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
