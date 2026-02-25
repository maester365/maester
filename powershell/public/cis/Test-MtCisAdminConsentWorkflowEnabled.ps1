<#
.SYNOPSIS
    Checks if the admin consent workflow is enabled

.DESCRIPTION
    The admin consent workflow should be enabled.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisAdminConsentWorkflowEnabled

    Returns true if admin consent workflow is enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisAdminConsentWorkflowEnabled
#>
function Test-MtCisAdminConsentWorkflowEnabled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -DisableCache

        Write-Verbose 'Executing checks'
        $checkAdminConsentWorkflowEnabled = $settings | Where-Object { $_.isEnabled -eq $true }

        $testResult = (($checkAdminConsentWorkflowEnabled | Measure-Object).Count -ge 1)

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant settings not comply with CIS recommendations.`n`n%TestResult%"
        }

        $resultMd = "| Setting | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($checkAdminConsentWorkflowEnabled) {
            $checkAdminConsentWorkflowEnabledResult = '✅ Pass'
        } else {
            $checkAdminConsentWorkflowEnabledResult = '❌ Fail'
        }

        $resultMd += "| Users can request admin consent to apps they are unable to consent to | $checkAdminConsentWorkflowEnabledResult |`n"


        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}