<#
.SYNOPSIS
    Ensure soft and hard matching for on-premises synchronization objects is blocked

.DESCRIPTION
    Soft and hard matching for on-premises synchronization objects is a feature that allows Entra ID to match users based on their userprincipalname, email address or other attributes.
    This can lead to unintended consequences, such as mismatching user data.

.EXAMPLE
    Test-MtEntraIDConnectSyncSoftHardMatching

    Returns true if soft and hard matching is blocked / disabled

.LINK
    https://maester.dev/docs/commands/Test-MtEntraIDConnectSyncSoftHardMatching
#>
function Test-MtEntraIDConnectSyncSoftHardMatching {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }
    $return = $true

    Write-Verbose "Checking if on-premises directory synchronization soft- and hard-match is blocked..."
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
        $onPremisesSynchronizationConfig = Invoke-MtGraphRequest -RelativeUri "directory/onPremisesSynchronization"

        $passResult = "✅ Pass"
        $failResult = "❌ Fail"

        $result = "| Policy | Value | Status |`n"
        $result += "| --- | --- | --- |`n"

        if ($onPremisesSynchronizationConfig.features.blockSoftMatchEnabled -eq $false) {
            $result += "| Block soft-match | $($onPremisesSynchronizationConfig.features.blockSoftMatchEnabled) | $failResult |`n"
            $return = $false
        } else {
            $result += "| Block soft-match | $($onPremisesSynchronizationConfig.features.blockSoftMatchEnabled) | $passResult |`n"
        }
        if ($onPremisesSynchronizationConfig.features.blockCloudObjectTakeoverThroughHardMatchEnabled -eq $false) {
            $result += "| Block hard-match | $($onPremisesSynchronizationConfig.features.blockCloudObjectTakeoverThroughHardMatchEnabled) | $failResult |`n"
            $return = $false
        } else {
            $result += "| Block hard-match | $($onPremisesSynchronizationConfig.features.blockCloudObjectTakeoverThroughHardMatchEnabled) | $passResult |`n"
        }

        if ($return) {
            $testResult = "Well done. On-premises directory synchronization soft- and hard-match is blocked.`n`n$($result)"
            Add-MtTestResultDetail -Result $testResult
        } else {
            $testResult = "On-premises directory synchronization soft-match and / or hard-match is allowed.`n`n$($result)"
            Add-MtTestResultDetail -Result $testResult
        }
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}