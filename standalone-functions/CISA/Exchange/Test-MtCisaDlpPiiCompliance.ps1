function Test-MtCisaDlpPiiCompliance {
    <#
    .SYNOPSIS
    Checks state of DLP for EXO

    .DESCRIPTION
    The DLP solution SHALL protect personally identifiable information (PII) and sensitive information, as defined by the agency.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaDlpPiiCompliance
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

    $policies = Get-DlpCompliancePolicy

    $resultPolicies = $policies | Where-Object {`
        $_.ExchangeLocation.DisplayName -contains "All" -and `
        $_.Workload -like "*Exchange*" -and `
        -not $_.IsSimulationPolicy -and `
        $_.Enabled
    }

    $rules = $resultPolicies | ForEach-Object {
        Get-DlpComplianceRule
    }

    $resultRules = $rules | Where-Object {`
        -not $_.Disabled -and `
        $_.Mode -eq "Enforce" -and `
        $_.BlockAccess -and `
        $_.BlockAccessScope -eq "All" -and `
        $_.NotifyPolicyTipDisplayOption -eq "Tip" -and `
        $_.AdvancedRule -like "*50b8b56b-4ef8-44c2-a924-03374f5831ce*" # All Full Names Sensitive Info Type
    }

    $testResult = ($resultRules | Measure-Object).Count -ge 1
    if ($rules) {
        $passResult = "✅ Pass"
        $failResult = "❌ Fail"
        $result = "| Status | Policy | Rule |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($item in ($rules | Sort-Object -Property ParentPolicyName,Name)) {
            if($item.Guid -in $resultRules.Guid){
            }
        }
    }


    return $testResult

}
