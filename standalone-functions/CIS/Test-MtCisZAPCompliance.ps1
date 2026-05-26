function Test-MtCisZAPCompliance {
    <#
    .SYNOPSIS
    Checks if the Zero-hour auto purge (ZAP) for Microsoft Teams is enabled

    .DESCRIPTION
    Zero-hour auto purge (ZAP) should be enabled for Microsoft Teams
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisZAPCompliance
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
        $null = Get-CsTenant -ErrorAction Stop
    } catch {
        Write-Verbose "Not connected to Microsoft Teams: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        Write-Verbose 'Get TeamsProtectionPolicy'
        $teamsProtectionPolicy = Get-TeamsProtectionPolicy | Select-Object ZapEnabled

        Write-Verbose 'Add policy to result if ZAP is not enabled'
        $result = $teamsProtectionPolicy | Where-Object { $_.ZapEnabled -ne 'True' }

        $testResult = ($result | Measure-Object).Count -eq 0
        if ($testResult) {
        } else {
        }


        return $testResult
    } catch {
        return $null
    }

}
