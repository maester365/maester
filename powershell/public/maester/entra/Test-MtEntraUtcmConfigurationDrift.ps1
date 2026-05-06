﻿function Test-MtEntraUtcmConfigurationDrift {
    <#
    .SYNOPSIS
    Checks for active configuration drifts reported by Microsoft Entra Unified Tenant Configuration Management (UTCM).

    .DESCRIPTION
    Uses the Microsoft Graph API (beta) to identify resources that have drifted from their
    managed baseline configuration. Active drifts indicate the tenant has deviated from the
    configuration managed by UTCM and remediation is required to restore compliance.

    .EXAMPLE
    Test-MtEntraUtcmConfigurationDrift

    Returns $true if no active configuration drifts are detected.

    .LINK
    https://maester.dev/docs/commands/Test-MtEntraUtcmConfigurationDrift
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        $drifts = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "admin/configurationManagement/configurationDrifts" -Filter "status eq 'active'"
        $testResult = ($drifts.Count -eq 0)

        if ($testResult) {
            $testResultMarkdown = "Well done. No active configuration drifts were detected by Microsoft Entra Unified Tenant Configuration Management (UTCM)."
        } else {
            $resultTable = "| Monitor | Resource | Resource Type | Current Value | Expected Value | Drift Detected |`n"
            $resultTable += "| --- | --- | --- | --- | --- | --- |`n"
            foreach ($drift in $drifts) {
                $detectedDate = if ($drift.driftDetectedDateTime) {
                    ([datetime]$drift.driftDetectedDateTime).ToString("yyyy-MM-dd HH:mm")
                } else {
                    "N/A"
                }
                $currentVal = if ($null -ne $drift.currentValue) { $drift.currentValue } else { "" }
                $expectedVal = if ($null -ne $drift.expectedValue) { $drift.expectedValue } else { "" }
                $resultTable += "| $($drift.monitorDisplayName) | $($drift.resourceDisplayName) | $($drift.resourceType) | ``$currentVal`` | ``$expectedVal`` | $detectedDate |`n"
            }
            $testResultMarkdown = "Found **$($drifts.Count)** active configuration drift(s) reported by Microsoft Entra UTCM.`n`n$resultTable"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
