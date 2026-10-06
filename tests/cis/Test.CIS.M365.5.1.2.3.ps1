function Test-MtCisCreateTenantDisallowed {
    <#
    .SYNOPSIS
        Checks if non-admin users are restricted from creating tenants

    .DESCRIPTION
        Non-admin users should be restricted from creating tenants.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.2.3, L1)

    .EXAMPLE
        Test-MtCisCreateTenantDisallowed

        Returns true if non-admin users are restricted from creating tenants.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisCreateTenantDisallowed
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.2.3',
        Title = 'Ensure ''Restrict non-admin users from creating tenants'' is set to ''Yes''',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1', 'Security'),
        Service = 'Graph',
        Author = 'oed-metzb',
        Contributor = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting settings...'
    $settings = (Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -DisableCache).defaultUserRolePermissions

    Write-Verbose 'Executing checks'
    $checkAllowedToCreateTenants = $settings | Where-Object { $_.allowedToCreateTenants -eq $false }

    $testResult = (($checkAllowedToCreateTenants | Measure-Object).Count -ge 1)

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant settings do not comply with CIS recommendations.`n`n%TestResult%"
    }

    $resultMd = "| Setting | Result |`n"
    $resultMd += "| --- | --- |`n"

    if ($checkAllowedToCreateTenants) {
        $checkAllowedToCreateTenantsResult = '✅ Pass'
    }
    else {
        $checkAllowedToCreateTenantsResult = '❌ Fail'
    }

    $resultMd += "| Restrict non-admin users from creating tenants | $checkAllowedToCreateTenantsResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
