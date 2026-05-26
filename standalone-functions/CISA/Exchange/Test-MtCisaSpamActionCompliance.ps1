function Test-MtCisaSpamActionCompliance {
    <#
    .SYNOPSIS
    Checks state of spam filter

    .DESCRIPTION
    Spam and high confidence spam SHALL be moved to either the junk email folder or the quarantine folder.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaSpamActionCompliance
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

    $policies = Get-HostedContentFilterPolicy

    $resultPolicies = $policies | Where-Object { `
        $_.SpamAction -in @("MoveToJmf","Quarantine") -and `
        $_.HighConfidenceSpamAction -in @("MoveToJmf","Quarantine")
    }

    $standard = $resultPolicies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $resultPolicies | Where-Object { `
        $_.RecommendedPolicyType -eq "Strict"
    }

    $testResult = $standard -and $strict -and (($resultPolicies|Measure-Object).Count -ge 1)

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Policy | Status |`n"
    $result += "| --- | --- |`n"
    if ($standard) {
        $result += "| Standard | $passResult |`n"
    } else {
        $result += "| Standard | $failResult |`n"
    }
    if ($strict) {
        $result += "| Strict | $passResult |`n`n"
    } else {
        $result += "| Strict | $failResult |`n`n"
    }

    $result += "| Policy Name | Spam Action | High Confidence Spam Action |`n"
    $result += "| --- | --- | --- |`n"
    foreach($item in $policies | Sort-Object -Property Identity){
        if($item.SpamAction -in @("MoveToJmf","Quarantine")){
            $resultSpamAction = $passResult
        }else{
            $resultSpamAction = $failResult
        }
        if($item.HighConfidenceSpamAction -in @("MoveToJmf","Quarantine")){
            $resultHighConfidenceSpamAction = $passResult
        }else{
            $resultHighConfidenceSpamAction = $failResult
        }
        $result += "| $($item.Identity) | $resultSpamAction | $resultHighConfidenceSpamAction |`n"
    }


    return $testResult

}
