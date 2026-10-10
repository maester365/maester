function Test-MtCisFormsPhishingProtectionEnabled {
    <#
    .SYNOPSIS
        Checks if the internal phishing protection for Microsoft Forms is enabled.

    .DESCRIPTION
        The internal phishing protection for Microsoft Forms should be enabled.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.3.5, L1)

    .EXAMPLE
        Test-MtCisFormsPhishingProtectionEnabled

        Returns true if the internal phishing protection for Microsoft Forms is enabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisFormsPhishingProtectionEnabled
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.3.5',
        Title = 'Ensure internal phishing protection for Forms is enabled',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Microsoft 365',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1', 'Security'),
        Service = 'Graph',
        Author = 'oed-metzb',
        Contributor = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $scopes = (Get-MgContext).Scopes
    $permissionMissing = "OrgSettings-Forms.Read.All" -notin $scopes
    if ($permissionMissing) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Missing Scope OrgSettings-Forms.Read.All"
        return $null
    }

    Write-Verbose 'Getting settings...'
    $settings = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "admin/forms/settings" -DisableCache

    Write-Verbose 'Executing checks'
    $CheckIsInOrgFormsPhishingScanEnabled = $settings | Where-Object { $_.isInOrgFormsPhishingScanEnabled -eq $true }

    $testResult = (($CheckIsInOrgFormsPhishingScanEnabled | Measure-Object).Count -ge 1)

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant settings do not comply with CIS recommendations.`n`n%TestResult%"
    }

    $resultMd = "| Setting | Result |`n"
    $resultMd += "| --- | --- |`n"

    if ($CheckIsInOrgFormsPhishingScanEnabled) {
        $CheckIsInOrgFormsPhishingScanEnabledResult = '✅ Pass'
    }
    else {
        $CheckIsInOrgFormsPhishingScanEnabledResult = '❌ Fail'
    }

    $resultMd += "| Add internal phishing protection | $CheckIsInOrgFormsPhishingScanEnabledResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
