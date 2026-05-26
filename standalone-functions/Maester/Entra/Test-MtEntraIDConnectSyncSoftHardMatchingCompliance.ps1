function Test-MtEntraIDConnectSyncSoftHardMatchingCompliance {
    <#
    .SYNOPSIS
    Ensure soft and hard matching for on-premises synchronization objects is blocked

    .DESCRIPTION
    Soft and hard matching for on-premises synchronization objects is a feature that allows Entra ID to match users based on their userprincipalname, email address or other attributes.
    This can lead to unintended consequences, such as mismatching user data.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtEntraIDConnectSyncSoftHardMatchingCompliance
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
    $return = $true

    Write-Verbose "Checking if on-premises directory synchronization soft- and hard-match is blocked..."
    try {
        $organizationConfig = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/organization'
    } catch {
        return $null
    }
    if ($organizationConfig.onPremisesSyncEnabled -ne $true) {
        return $null
    }

    try {
        $onPremisesSynchronizationConfig = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/directory/onPremisesSynchronization'
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
        } else {
            $testResult = "On-premises directory synchronization soft-match and / or hard-match is allowed.`n`n$($result)"
        }
        return $return
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 403) {
        } else {
        }
        return $null
    }

}
