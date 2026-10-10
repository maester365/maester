function Test-MtCisAdminConsentWorkflowEnabled {
    <#
    .SYNOPSIS
        Checks if the admin consent workflow is enabled

    .DESCRIPTION
        The admin consent workflow should be enabled.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.5.2, L1)

    .EXAMPLE
        Test-MtCisAdminConsentWorkflowEnabled

        Returns true if admin consent workflow is enabled

    .LINK
        https://maester.dev/docs/commands/Test-MtCisAdminConsentWorkflowEnabled
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.5.2',
        Title = 'Ensure the admin consent workflow is enabled',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Entra ID',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1', 'Security'),
        Service = 'Graph',
        Author = 'oed-metzb',
        Contributor = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting settings...'
    $settings = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -DisableCache

    Write-Verbose 'Executing checks'
    $checkAdminConsentWorkflowEnabled = $settings | Where-Object { $_.isEnabled -eq $true }

    $testResult = (($checkAdminConsentWorkflowEnabled | Measure-Object).Count -ge 1)

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant settings do not comply with CIS recommendations.`n`n%TestResult%"
    }

    $resultMd = "| Setting | Result |`n"
    $resultMd += "| --- | --- |`n"

    if ($checkAdminConsentWorkflowEnabled) {
        $checkAdminConsentWorkflowEnabledResult = '✅ Pass'
    }
    else {
        $checkAdminConsentWorkflowEnabledResult = '❌ Fail'
    }

    $resultMd += "| Users can request admin consent to apps they are unable to consent to | $checkAdminConsentWorkflowEnabledResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
