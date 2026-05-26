function Test-MtCisSafeAntiPhishingPolicyCompliance {
    <#
    .SYNOPSIS
    Checks if the anti-phishing policy matches CIS recommendations

    .DESCRIPTION
    The anti-phishing policy should be enabled, and the settings for PhishThresholdLevel, EnableMailboxIntelligenceProtection, EnableMailboxIntelligence, EnableSpoofIntelligence controls match CIS recommendations
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisSafeAntiPhishingPolicyCompliance
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

    try {
        $sku = Get-MgSubscribedSku | Where-Object { $_.ServicePlans.ServicePlanName -match 'MDE_ATP|THREAT_INTELLIGENCE|ATP_ENTERPRISE' }
        if ($null -eq $sku) {
            Write-Verbose "Microsoft Defender for Office 365 P1 license not found"
            return $null
        }
    } catch {
        Write-Verbose "License check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        Write-Verbose 'Getting Anti Phishing Policy...'
        $policies = Get-AntiPhishPolicy

        # We grab the default policy as that is what CIS checks
        $policy = $policies | Where-Object { $_.IsDefault -eq $true }

        $antiPhishingPolicyCheckList = @()

        # Enabled should be True
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'Enabled'
            'Value'     = 'True'
        }

        # EnableMailboxIntelligenceProtection should be True
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'EnableMailboxIntelligenceProtection'
            'Value'     = 'True'
        }

        # EnableMailboxIntelligence should be True
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'EnableMailboxIntelligence'
            'Value'     = 'True'
        }

        # EnableSpoofIntelligence should be True
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSpoofIntelligence'
            'Value'     = 'True'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()

        foreach ($check in $antiPhishingPolicyCheckList) {
            $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
            if ($checkResult) {
                #If the check fails, add it to the list so we can report on it later
                $failedCheckList += $check.CheckName
            }
        }

        # Custom check for PhishThresholdLevel
        # Because it is not exact match, the above logic won't work. Manual check to see if PhishThresholdLevel is 2 or greater
        if ($policy | Where-Object { $_.PhishThresholdLevel -le 1 }) {
            #If the check fails, add it to the list so we can report on it later
            $failedCheckList += 'PhishThresholdLevel'
        }

        # We didn't use this in the foreach loop above, but we need to add it now so we get results in the output for the separate check
        $antiPhishingPolicyCheckList += [pscustomobject] @{
            'CheckName' = 'PhishThresholdLevel'
        }

        $testResult = ($failedCheckList | Measure-Object).Count -eq 0
        return $testResult
    } catch {
        return $null
    }

}
