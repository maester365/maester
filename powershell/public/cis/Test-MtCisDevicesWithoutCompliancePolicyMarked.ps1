function Test-MtCisDevicesWithoutCompliancePolicyMarked {
    <#
    .SYNOPSIS
        Checks if devices without a compliance policy assigned are marked "not compliant".
    
    .DESCRIPTION
        Devices without a compliance policy assigned should be marked "not compliant".
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    
    .EXAMPLE
        Test-MtCisDevicesWithoutCompliancePolicyMarked
    
        Returns true if devices without a compliance policy assigned are marked "not compliant".
    
    .LINK
        https://maester.dev/docs/commands/Test-MtCisDevicesWithoutCompliancePolicyMarked
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
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
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}