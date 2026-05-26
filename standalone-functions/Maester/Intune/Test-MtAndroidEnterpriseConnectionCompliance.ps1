function Test-MtAndroidEnterpriseConnectionCompliance {
    <#
    .SYNOPSIS
    Check the health of the Android Enterprise connection for Intune.

    .DESCRIPTION
    The Android Enterprise connection is required to synchronize Android enterprise apps and allow Android enrollment with Microsoft Intune. This command checks if the connection is valid and not expired.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAndroidEnterpriseConnectionCompliance
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
    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        Write-Verbose 'Retrieving Android Enterprise connection status...'
        $androidEnterpriseSettings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/androidManagedStoreAccountEnterpriseSettings'

        if (-not $androidEnterpriseSettings -or $androidEnterpriseSettings.bindStatus -eq 'notBound') {
            throw [System.Management.Automation.ItemNotFoundException]::new('Android Enterprise is not configured or bound.')
        }

        $lastSyncDiffDays = [System.Math]::Floor(((Get-Date) - [datetime]$androidEnterpriseSettings.lastAppSyncDateTime).TotalDays)
        return $androidEnterpriseSettings.bindStatus -eq 'boundAndValidated' -and $androidEnterpriseSettings.lastAppSyncStatus -eq 'success' -and $lastSyncDiffDays -le 1
    } catch [System.Management.Automation.ItemNotFoundException] {
    } catch {
        return $null
    }

}
