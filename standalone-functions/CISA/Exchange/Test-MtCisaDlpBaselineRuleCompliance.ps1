function Test-MtCisaDlpBaselineRuleCompliance {
    <#
    .SYNOPSIS
    Checks state of baseline CISA rules for DLP in EXO

    .DESCRIPTION
    At a minimum, the DLP solution SHALL restrict sharing credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN) via email.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaDlpBaselineRuleCompliance
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

    $sits = [pscustomobject]@{
        ccn  = "*50842eb7-edc8-4019-85dd-5a5c1f2bb085*" # Credit Card Number
        ssn  = "*a44669fe-0d48-453d-a9b1-2cc83f2cba77*" # U.S. Social Security Number (SSN)
        itin = "*e55e2a32-f92d-4985-a35d-a0b269eb687b*" # U.S. Individual Taxpayer Identification Number (ITIN)
    }

    $resultRules = $rules | Where-Object {`
        -not $_.Disabled -and `
        $_.Mode -eq "Enforce" -and `
        $_.BlockAccess -and `
        $_.BlockAccessScope -eq "All" -and `
        $_.NotifyPolicyTipDisplayOption -eq "Tip" -and (`
            $_.AdvancedRule -like $sits.ccn -or`
            $_.AdvancedRule -like $sits.ssn -or`
            $_.AdvancedRule -like $sits.itin
        )
    }

    $resultCcn  = $resultRules.AdvancedRule -join "`n" -like $sits.ccn
    $resultSsn  = $resultRules.AdvancedRule -join "`n" -like $sits.ssn
    $resultItin = $resultRules.AdvancedRule -join "`n" -like $sits.itin

    $resultComposite = $resultCcn -and $resultSsn -and $resultItin


    if ($resultComposite) {
    } else {
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "Required Rules:`n`n"
    $result += "| Credit Card Number | U.S. Social Security Number | U.S. Individual Taxpayer Identification Number |`n"
    $result += "| --- | --- | --- |`n"
    $result += "| $(if($resultCcn){$passResult}else{$failResult}) | $(if($resultSsn){$passResult}else{$failResult}) | $(if($resultItin){$passResult}else{$failResult}) |`n`n"
    $result += "Rule Relationships:`n`n"
    $result += "| Status | Policy | Rule |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($item in ($rules | Sort-Object -Property ParentPolicyName,Name)) {
        if($item.Guid -in $resultRules.Guid){
        }
    }


    return $resultComposite

}
