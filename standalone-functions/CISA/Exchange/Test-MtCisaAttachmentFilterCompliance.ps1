function Test-MtCisaAttachmentFilterCompliance {
    <#
    .SYNOPSIS
    Checks state of preset security policies

    .DESCRIPTION
    Emails SHALL be filtered by attachment file types
    Emails SHALL be scanned for malware.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaAttachmentFilterCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $policies = Get-MtExoThreatPolicyMalware

    $failingPolicies = $policies | Where-Object { $_.IsEnabled -and -not $_.EnableFileFilter }
    $testResult = ($failingPolicies | Measure-Object).Count -eq 0

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"

    $result = "| Policy name | Enabled | EnableFileFilter | Extensions | Result |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach ($item in $policies) {
        if ($item.FileTypes) {
            $resultFilesList = ($item.FileTypes | Select-Object -First 5) -join ", "
            $resultFilesList += ", & $(($item.FileTypes|Measure-Object).Count -5) others"
        } else {
            $resultFilesList = ""
        }
        if (-not $item.IsEnabled) {
            $result += "| $($item.Identity) | $false | $($item.EnableFileFilter) | $resultFilesList | $($skipResult) |`n"
        } elseif ($item.EnableFileFilter) {
            $result += "| $($item.Identity) | $true | $($item.EnableFileFilter) | $resultFilesList | $($passResult) |`n"
        } else {
            $result += "| $($item.Identity) | $true | $($item.EnableFileFilter) | $resultFilesList | $($failResult) |`n"
        }
    }
    return $testResult

}
