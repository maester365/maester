<#
.SYNOPSIS
    Ensure soft and hard matching for on-premises synchronization objects is blocked

.DESCRIPTION
    Soft and hard matching for on-premises synchronization objects is a feature that allows Entra ID to match users based on their userprincipalname, email address or other attributes.
    This can lead to unintended consequences, such as mismatching user data.

.EXAMPLE
    Test-EntraConnectSyncVersion

    Returns true if latest version of Entra Connect Sync Server

.LINK
    https://maester.dev/docs/commands/Test-EntraConnectSyncVersion
#>
function Test-EntraConnectSyncVersion {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }
    $return = $true

    Write-Verbose "Checking if on-premises directory synchronization is enabled..."
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

        $LatestVersion = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/MicrosoftDocs/entra-docs/refs/heads/main/docs/identity/hybrid/connect/reference-connect-version-history.md"
        # Parse the latest version based on the end of support table.
        # The latest version is the one without any end of support date
        if ( $LatestVersion -match "\|\[(\d+.\d+.\d+.\d+)\]\(.*\)\|\|" ) {
            $LatestVersionNumber = $Matches[1]
        } else {
            $LatestVersionNumber = "Unknown"
        }
        # Create a table of older versions with end of support date
        $LegacyVersionTable = $LatestVersion -split "`n" | ForEach-Object {
            if ( $_ -match "\|\[(\d+.\d+.\d+.\d+)\]\(.*\)\|(.+)\|") {
                [pscustomobject]@{
                    VersionNumber    = [version]$Matches[1]
                    EndOfSupportDate = [datetime]( $Matches[2] -replace ' \(.*$' )
                }
            }
        }

        $onPremisesSynchronizationConfig = Invoke-MtGraphRequest -RelativeUri "directory/onPremisesSynchronization" -ApiVersion beta

        $passResult = "✅ Pass"
        $failResult = "❌ Fail"

        $result = "| Entra Connect Server | Version | End of Support | Status |`n"
        $result += "| --- | --- | --- | --- |`n"

        $onPremisesSynchronizationConfig | ForEach-Object {
            $EntraConnectSyncVersion = [version]$_.configuration.synchronizationClientVersion
            $EntraConnectServerName = $_.configuration.currentExportData.clientMachineName
            $EndOfSupportDate = $LegacyVersionTable | Sort-Object VersionNumber | ForEach-Object {
                if ( $EntraConnectSyncVersion -le $_.VersionNumber ) {
                    $_.EndOfSupportDate.ToString("yyyy-MM-dd")
                }
            }
            if ($EntraConnectSyncVersion -lt [version]$LatestVersionNumber) {
                $return = $false
                $result += "| $($EntraConnectServerName) | $($EntraConnectSyncVersion) | $($EndOfSupportDate) | $failResult |`n"
            } else {
                $result += "| $($EntraConnectServerName) | $($EntraConnectSyncVersion) | N/A | $passResult |`n"
            }
        }

        if ($return) {
            $testResult = "Well done. Your Entra Connect Sync server(s) are up-to-date. `n`n$($result)"
            Add-MtTestResultDetail -Result $testResult
        } else {
            $testResult = "Your Entra Connect Sync server(s) are not on the latest version.`n`n$($result)"
            Add-MtTestResultDetail -Result $testResult
        }
        return $return
    } Catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}