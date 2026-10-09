function Test-MtCisDevicesWithoutCompliancePolicyMarked {
    <#
    .SYNOPSIS
        Checks if devices without a compliance policy assigned are marked "not compliant".

    .DESCRIPTION
        Devices without a compliance policy assigned should be marked "not compliant".
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (4.1, L1)

    .EXAMPLE
        Test-MtCisDevicesWithoutCompliancePolicyMarked

        Returns true if devices without a compliance policy assigned are marked "not compliant".

    .LINK
        https://maester.dev/docs/commands/Test-MtCisDevicesWithoutCompliancePolicyMarked
    #>
    [MaesterTest(
        Id = 'CIS.M365.4.1',
        Title = 'Ensure devices without a compliance policy are marked ''not compliant''',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1', 'Security'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'oed-metzb',
        Contributor = ('Mynster9361', 'Korthal-Maiyn')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting settings...'
    $settings = Invoke-MtGraphRequest -RelativeUri "deviceManagement/settings" -DisableCache

    Write-Verbose 'Executing checks'
    $checkSecureByDefault = $settings | Where-Object { $_.secureByDefault -eq $true }

    $testResult = (($checkSecureByDefault | Measure-Object).Count -ge 1)

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant settings do not comply with CIS recommendations.`n`n%TestResult%"
    }

    $resultMd = "| Setting | Result |`n"
    $resultMd += "| --- | --- |`n"

    if ($checkSecureByDefault) {
        $checkSecureByDefaultResult = '✅ Pass'
    }
    else {
        $checkSecureByDefaultResult = '❌ Fail'
    }

    $resultMd += "| Mark devices with no compliance policy assigned as 'Not compliant' | $checkSecureByDefaultResult |`n"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
