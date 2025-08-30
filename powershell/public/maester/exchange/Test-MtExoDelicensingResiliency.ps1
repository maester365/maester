<#
.SYNOPSIS
    Checks if Delicensing Resiliency is enabled in Exchange Online

.DESCRIPTION
    Delicensing Resiliency should be enabled to maintain access to mailboxes
    when licenses are removed, providing a grace period before access is lost.
    This helps prevent immediate disruption when licenses expire or are reassigned.

.EXAMPLE
    Test-MtExoDelicensingResiliency

    Returns true if Delicensing Resiliency is enabled

.LINK
    https://maester.dev/docs/commands/Test-MtExoDelicensingResiliency
#>
function Test-MtExoDelicensingResiliency {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose "Checking license requirements..."
    try {
        $licenseCount = Get-MtLicenseInformation -Product ExoLicenseCount
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
        Add-MtTestResultDetail -SkippedBecause "Custom" -SkippedCustomReason "Not enough non-trial licenses. See [Delicensing Resiliency](https://learn.microsoft.com/en-us/Exchange/recipients-in-exchange-online/manage-user-mailboxes/exchange-online-delicensing-resiliency)"
        return $null
    }

    try {
        # License requirements are met or couldn't be determined, proceed with the actual delicensing check
        Write-Verbose "Proceeding with Delicensing Resiliency status check..."
        Write-Verbose "Getting Organization Configuration..."
        $organizationConfig = Get-MtExo -Request OrganizationConfig

        $delicensingState = $organizationConfig.DelayedDelicensingEnabledState
        $result = $delicensingState -match "Enabled: True"

        if ($result) {
            $testResultMarkdown = "Well done. Delicensing Resiliency is enabled.`n`n"
        } else {
            $testResultMarkdown = "'DelayedDelicensingEnabled' in OrganizationConfig should be ``True`` and is ``False```n`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    return $result
}
