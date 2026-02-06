<#
.SYNOPSIS
    Checks if the internal phishing protection for Microsoft Forms is enabled.

.DESCRIPTION
    The internal phishing protection for Microsoft Forms should be enabled.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisFormsPhishingProtectionEnabled

    Returns true if the internal phishing protection for Microsoft Forms is enabled.

.LINK
    https://maester.dev/docs/commands/Test-MtCisFormsPhishingProtectionEnabled
#>
function Test-MtCisFormsPhishingProtectionEnabled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $scopes = (Get-MgContext).Scopes
    $permissionMissing = "OrgSettings-Forms.Read.All" -notin $scopes
    if($permissionMissing){
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Missing Scope OrgSettings-Forms.Read.All"
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "admin/forms/settings" -DisableCache

        Write-Verbose 'Executing checks'
        $CheckIsInOrgFormsPhishingScanEnabled = $settings | Where-Object { $_.isInOrgFormsPhishingScanEnabled -eq $true }

        $testResult = (($CheckIsInOrgFormsPhishingScanEnabled | Measure-Object).Count -ge 1)

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant settings not comply with CIS recommendations.`n`n%TestResult%"
        }

        $resultMd = "| Setting | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($CheckIsInOrgFormsPhishingScanEnabled) {
            $CheckIsInOrgFormsPhishingScanEnabledResult = '✅ Pass'
        } else {
            $CheckIsInOrgFormsPhishingScanEnabledResult = '❌ Fail'
        }

        $resultMd += "| Add internal phishing protection | $CheckIsInOrgFormsPhishingScanEnabledResult |`n"

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}