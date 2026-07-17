function Test-MtEntraIDConnectSyncOnPremisesObjectIdentifierUpdatesBlocked {
    <#
    .SYNOPSIS
    Checks if the temporary bypass for onPremisesObjectIdentifier updates is disabled

    .DESCRIPTION
    Microsoft Entra ID added hard match security protections that can block a hard match when the target cloud
    account already has onPremisesObjectIdentifier set, is assigned a privileged Microsoft Entra role, or is
    eligible for a privileged Microsoft Entra role.

    The allowOnPremUpdateOfOnPremisesObjectIdentifierEnabled tenant feature flag temporarily bypasses these
    protections. It's disabled by default and should stay disabled unless a validated migration, recovery, or
    consolidation scenario requires a temporary bypass.

    .EXAMPLE
    Test-MtEntraIDConnectSyncOnPremisesObjectIdentifierUpdatesBlocked

    Returns true if the temporary bypass for onPremisesObjectIdentifier updates is disabled

    .LINK
    https://maester.dev/docs/commands/Test-MtEntraIDConnectSyncOnPremisesObjectIdentifierUpdatesBlocked
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose "Checking if the temporary bypass for onPremisesObjectIdentifier updates is disabled..."
    try {
        $organizationConfig = Invoke-MtGraphRequest -RelativeUri "organization"
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
    if ($organizationConfig.onPremisesSyncEnabled -ne $true) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'OnPremisesSynchronization is not configured'
        return $null
    }

    try {
        $onPremisesSynchronizationConfig = Invoke-MtGraphRequest -RelativeUri "directory/onPremisesSynchronization" -ApiVersion beta

        $bypassEnabled = $onPremisesSynchronizationConfig.features.allowOnPremUpdateOfOnPremisesObjectIdentifierEnabled -eq $true

        if ($bypassEnabled) {
            $testResult = "The temporary bypass **allowOnPremUpdateOfOnPremisesObjectIdentifierEnabled** is currently *enabled* for this tenant.`n`n" `
                + "This reduces the hard match security protections that block an on-premises object from taking over a cloud account that already has onPremisesObjectIdentifier set, or that's assigned or eligible for a privileged Microsoft Entra role.`n`n" `
                + "Disable this flag as soon as your migration, recovery, or consolidation work is complete."
        } else {
            $testResult = "Well done. The temporary bypass for onPremisesObjectIdentifier updates isn't enabled, so hard match security protections remain in effect."
        }
        Add-MtTestResultDetail -Result $testResult
        return -not $bypassEnabled
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 403) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}

