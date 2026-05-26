function Test-MtDeviceRegistrationLocalAdminsRegisteringUserCompliance {
    <#
    .SYNOPSIS
    Tests whether registering users are configured as local administrators on devices during Microsoft Entra join.

    .DESCRIPTION
    Registering users should not be added as local administrators on the device during Microsoft Entra join.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtDeviceRegistrationLocalAdminsRegisteringUserCompliance
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
    Write-Verbose 'Testing Entra Device Registration Policy configuration for Entra Join local admin settings'
    try {
        $deviceRegistrationPolicy = @(Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy')
        $testResult = '```' + "`n"
        $testResult += $deviceRegistrationPolicy.azureADJoin.localAdmins | ConvertTo-Json
        $testResult += "`n"
        $testResult += '```'
        return $deviceRegistrationPolicy.azureADJoin.localAdmins.registeringUsers.'@odata.type' -eq '#microsoft.graph.noDeviceRegistrationMembership'
    } catch {
        return $null
    }

}
