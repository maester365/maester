function Test-MtAdRecycleBinStatus {
    <#
    .SYNOPSIS
    Retrieves the Active Directory Recycle Bin status.

    .DESCRIPTION
    This test checks whether the Active Directory Recycle Bin is enabled in the forest.
    The Recycle Bin provides enhanced protection against accidental deletion by allowing
    recovery of deleted objects without restoring from backup.

    .EXAMPLE
    Test-MtAdRecycleBinStatus

    Returns $true if Recycle Bin data is accessible.
    The test result includes whether the Recycle Bin is enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdRecycleBinStatus
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $forest = $adState.Forest
    $optionalFeatures = $adState.OptionalFeatures

    # Check if Recycle Bin optional feature is enabled
    $recycleBinFeature = $optionalFeatures | Where-Object { $_.Name -eq "Recycle Bin Feature" }
    $isEnabled = $false
    $enabledScopes = @()

    if ($recycleBinFeature) {
        $isEnabled = $recycleBinFeature.EnabledScopes.Count -gt 0
        $enabledScopes = $recycleBinFeature.EnabledScopes
    }

    # Test passes if we successfully retrieved Recycle Bin status
    $testResult = $null -ne $recycleBinFeature -or $optionalFeatures.Count -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Recycle Bin Enabled | $isEnabled |`n"
        $result += "| Forest Name | $($forest.Name) |`n"
        $result += "| Forest Functional Level | $($forest.ForestMode) |`n"

        if ($isEnabled -and $enabledScopes.Count -gt 0) {
            $result += "| Enabled Scopes | $($enabledScopes -join ', ') |`n"
        }

        $statusMessage = if ($isEnabled) { "✅ Enabled - Deleted objects can be recovered from the Recycle Bin" } else { "⚠️ Disabled - Deleted objects can only be recovered through tombstone reanimation or backup restore" }
        $result += "| Status | $statusMessage |`n"

        # Check if forest level supports Recycle Bin (requires Windows Server 2008 R2 or higher)
        $supportedLevels = @("Windows2008R2Forest", "Windows2012Forest", "Windows2012R2Forest", "Windows2016Forest", "Windows2025Forest")
        $forestLevelSupported = $supportedLevels -contains $forest.ForestMode

        if (-not $isEnabled -and -not $forestLevelSupported) {
            $result += "| Note | Forest functional level must be Windows Server 2008 R2 or higher to enable Recycle Bin |`n"
        }

        $testResultMarkdown = "The Active Directory Recycle Bin status has been retrieved. The Recycle Bin is currently $(if($isEnabled){'ENABLED'}else{'DISABLED'}).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Recycle Bin status. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}

