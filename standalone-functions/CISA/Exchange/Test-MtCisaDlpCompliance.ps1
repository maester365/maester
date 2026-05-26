function Test-MtCisaDlpCompliance {
    <#
    .SYNOPSIS
    Checks state of DLP for EXO

    .DESCRIPTION
    A DLP solution SHALL be used.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaDlpCompliance
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

    try {
        $sccSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.ComputerName -match 'compliance' -and $_.State -eq 'Opened' }
        if ($null -eq $sccSession) {
            Write-Verbose "Not connected to Security & Compliance Center"
            return $null
        }
    } catch {
        Write-Verbose "Security & Compliance connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $policies = Get-DlpCompliancePolicy | Where-Object { $_.ExchangeLocation.DisplayName -contains "All" }

    $resultPolicies = $policies | Where-Object {`
        $_.Workload -like "*Exchange*" -and `
        -not $_.IsSimulationPolicy -and `
        $_.Enabled
    }

    $testResult = ($resultPolicies | Measure-Object).Count -ge 1
    if ($policies) {
        $passResult = "✅ Pass"
        $failResult = "❌ Fail"
        $result = "| Name | Status | Description |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($item in ($policies | Sort-Object -Property name)) {
            if($item.Guid -in $resultPolicies.Guid){
            }
        }
    }


    return $testResult

}
