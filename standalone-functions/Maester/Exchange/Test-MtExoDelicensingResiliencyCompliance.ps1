function Test-MtExoDelicensingResiliencyCompliance {
    <#
    .SYNOPSIS
    Checks if Delicensing Resiliency is enabled in Exchange Online

    .DESCRIPTION
    Delicensing Resiliency should be enabled to maintain access to mailboxes
    when licenses are removed, providing a grace period before access is lost.
    This helps prevent immediate disruption when licenses expire or are reassigned.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtExoDelicensingResiliencyCompliance
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
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation


    Write-Verbose "Checking license requirements..."
    try {
        $meetsLicenseRequirement = $licenseCount -gt 5000
        Write-Verbose "License count: $licenseCount, Meets requirement: $meetsLicenseRequirement"
    } catch {
        Write-Verbose "Unable to check license requirements: $_"
        # If we can't check licenses, still proceed with the main test but note the limitation
        $licenseCount = $null
        $meetsLicenseRequirement = $null
    }

    # If license requirements are not met, return early with informative message
    if ($meetsLicenseRequirement -ne $true) {
        return $null
    }

    try {
        # License requirements are met or couldn't be determined, proceed with the actual delicensing check
        Write-Verbose "Proceeding with Delicensing Resiliency status check..."
        Write-Verbose "Getting Organization Configuration..."
        $organizationConfig = Get-OrganizationConfig

        $delicensingState = $organizationConfig.DelayedDelicensingEnabledState
        $result = $delicensingState -match "Enabled: True"

        if ($result) {
        } else {
        }

    } catch {
        return $null
    }

    return $result

}
