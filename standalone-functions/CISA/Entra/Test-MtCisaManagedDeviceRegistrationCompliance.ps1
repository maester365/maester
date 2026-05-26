function Test-MtCisaManagedDeviceRegistrationCompliance {
    <#
    .SYNOPSIS
    Checks if a policy is enabled requiring a managed device for registration

    .DESCRIPTION
    Managed Devices SHOULD be required to register MFA.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaManagedDeviceRegistrationCompliance
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

    if($EntraIDPlan -eq "Free"){
        return $null
    }

    $result = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq "enabled" }

    if($SkipHybridJoinCheck){
        $policies = $result | Where-Object {`
            $_.conditions.applications.includeUserActions -contains "urn:user:registersecurityinfo" -and `
            $_.conditions.users.includeUsers -contains "All" -and `
            $_.grantControls.builtInControls -contains "compliantDevice" }
    }else{
        $policies = $result | Where-Object {`
            $_.conditions.applications.includeUserActions -contains "urn:user:registersecurityinfo" -and `
            $_.conditions.users.includeUsers -contains "All" -and `
            $_.grantControls.builtInControls -contains "compliantDevice" -and `
            $_.grantControls.builtInControls -contains "domainJoinedDevice" -and `
            $_.grantControls.operator -eq "OR" }
    }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult -and $SkipHybridJoinCheck) {
    } elseif ($testResult) {
    } else {
    }

    return $testResult

}
