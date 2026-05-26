function Test-MtCisSafeAttachmentCompliance {
    <#
    .SYNOPSIS
    Checks if the Safe Attachments policy is enabled

    .DESCRIPTION
    The Safe Attachments policy is enabled
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisSafeAttachmentCompliance
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
        Write-Verbose 'Getting Safe Attachment Policy...'
        $policies = Get-SafeAttachmentPolicy

        # We grab the default policy as that is what CIS checks
        $policy = $policies | Where-Object { $_.Name -eq 'Built-In Protection Policy' }

        $safeAttachmentCheckList = @()

        #Enable
        $safeAttachmentCheckList += [pscustomobject] @{
            'CheckName' = 'Enable'
            'Value'     = 'True'
        }

        #Action
        $safeAttachmentCheckList += [pscustomobject] @{
            'CheckName' = 'Action'
            'Value'     = 'Block'
        }

        #QuarantineTag
        $safeAttachmentCheckList += [pscustomobject] @{
            'CheckName' = 'QuarantineTag'
            'Value'     = 'AdminOnlyAccessPolicy'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()

        foreach ($check in $safeAttachmentCheckList) {
            $checkResult = $policy | Where-Object { $_.($check.CheckName) -notmatch $check.Value }
            if ($checkResult) {
                #If the check fails, add it to the list so we can report on it later
                $failedCheckList += $check.CheckName
            }
        }

        $testResult = ($failedCheckList | Measure-Object).Count -eq 0
        return $testResult
    } catch {
        return $null
    }

}
