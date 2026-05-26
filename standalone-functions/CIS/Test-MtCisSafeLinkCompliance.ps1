function Test-MtCisSafeLinkCompliance {
    <#
    .SYNOPSIS
    Checks if safe links for office applications are Enabled

    .DESCRIPTION
    Safe links should be enabled for office applications (Exchange Teams Office 365 Apps)
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisSafeLinkCompliance
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
        Write-Verbose 'Getting Safe Links Policy...'

        # Get the name of highest priority policy
        $priority0Policy = Get-SafeLinksRule | Where-Object { $_.Priority -eq '0' }

        # Get policy highest priority policy
        $policy = Get-SafeLinksPolicy | Where-Object { $_.Name -eq $priority0Policy }

        $safeLinkCheckList = @()

        #EnableSafeLinksForEmail
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSafeLinksForEmail'
            'Value'     = 'True'
        }

        #EnableSafeLinksForTeams
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSafeLinksForTeams'
            'Value'     = 'True'
        }

        #EnableSafeLinksForOffice
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'EnableSafeLinksForOffice'
            'Value'     = 'True'
        }

        #TrackClicks
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'TrackClicks'
            'Value'     = 'True'
        }

        #AllowClickThrough
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'AllowClickThrough'
            'Value'     = 'False'
        }

        #ScanUrls
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'ScanUrls'
            'Value'     = 'True'
        }

        #EnableForInternalSenders
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'EnableForInternalSenders'
            'Value'     = 'True'
        }

        #DeliverMessageAfterScan
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'DeliverMessageAfterScan'
            'Value'     = 'True'
        }

        #DisableUrlRewrite
        $safeLinkCheckList += [pscustomobject] @{
            'CheckName' = 'DisableUrlRewrite'
            'Value'     = 'False'
        }

        Write-Verbose 'Executing checks'
        $failedCheckList = @()
        foreach ($check in $safeLinkCheckList) {
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
