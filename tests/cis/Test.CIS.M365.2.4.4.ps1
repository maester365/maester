function Test-MtCisZAP {
    <#
    .SYNOPSIS
    Checks if the Zero-hour auto purge (ZAP) for Microsoft Teams is enabled

    .DESCRIPTION
    Zero-hour auto purge (ZAP) should be enabled for Microsoft Teams
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.4.4, L1)

    .EXAMPLE
    Test-MtCisZAP

    Returns true if Zero-hour auto purge (ZAP) is enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisZAP
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.4.4',
        Title = 'Ensure Zero-hour auto purge for Microsoft Teams is on (Only Checks ZAP is enabled)',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1'),
        Service = 'Teams',
        License = 'THREAT_INTELLIGENCE',
        Author = 'NZLostboy',
        Contributor = 'Korthal-Maiyn'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Get TeamsProtectionPolicy'
    $teamsProtectionPolicy = Get-TeamsProtectionPolicy | Select-Object ZapEnabled

    Write-Verbose 'Add policy to result if ZAP is not enabled'
    $result = $teamsProtectionPolicy | Where-Object { $_.ZapEnabled -ne 'True' }

    $testResult = ($result | Measure-Object).Count -eq 0
    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has Zero-hour auto purge (ZAP) enabled for Microsoft Teams:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have Zero-hour auto purge (ZAP) enabled for Microsoft Teams:`n`n%TestResult%"
    }

    $resultMd = "| Zero-hour auto purge (ZAP) |`n"
    $resultMd += "| --- |`n"
    if ($testResult) {
        $itemResult = '✅ Enabled'
    } else {
        $itemResult = '❌ Not Enabled'
    }
    $resultMd += "| $($itemResult) |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
