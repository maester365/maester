<#
.SYNOPSIS
    Checks if non-admin users are restricted from creating tenants

.DESCRIPTION
    Non-admin users should be restricted from creating tenants.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisCreateTenantDisallowed

    Returns true if non-admin users are restricted from creating tenants.

.LINK
    https://maester.dev/docs/commands/Test-MtCisCreateTenantDisallowed
#>
function Test-MtCisCreateTenantDisallowed {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $settings = (Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy").defaultUserRolePermissions

        Write-Verbose 'Executing checks'
        $checkAllowedToCreateTenants = $settings | Where-Object { $_.allowedToCreateTenants -eq $false }

        $testResult = (($checkAllowedToCreateTenants | Measure-Object).Count -ge 1)

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant settings not comply with CIS recommendations.`n`n%TestResult%"
        }

        $resultMd = "| Setting | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($checkAllowedToCreateTenants) {
            $checkAllowedToCreateTenantsResult = '✅ Pass'
        } else {
            $checkAllowedToCreateTenantsResult = '❌ Fail'
        }

        $resultMd += "| Restrict non-admin users from creating tenants | $checkAllowedToCreateTenantsResult |`n"

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}