function Test-MtManagementGroupWriteRequirementCompliance {
    <#
    .SYNOPSIS
    Checks if write permissions are required to create new management groups

    .DESCRIPTION
    This test ensures that only users with explicit write access can create new management groups.
    This is important to prevent unauthorized creation of management groups which could lead to security risks.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtManagementGroupWriteRequirementCompliance
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
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    # Get all management groups in the tenant and filter the tenant root management group by id
    $rootManagementGroup = Get-MtAzureManagementGroup | Where-Object { $_.id -match "$($_.properties.tenantid)$" }

    if (!$rootManagementGroup) {
        Write-Verbose "Tenant Root Group not found in management groups."
        return $null
    }

    try {
        # Query the management group settings to check authorization requirements
        $settingResponse = Invoke-MtAzureRequest `
            -RelativeUri "/providers/Microsoft.Management/managementGroups/$($rootManagementGroup.name)/settings/default" `
            -ApiVersion "2020-05-01"

        # Extract the setting that controls write permissions for group creation
        $requireWritePermissions = $settingResponse.properties.requireAuthorizationForGroupCreation
        Write-Verbose "Require write permissions for creating management groups: $requireWritePermissions"

        $testResult = $requireWritePermissions -eq $true

        # Build result message based on the setting
        return $testResult
    }
    catch {
        return $null
    }

}
