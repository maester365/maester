<#
.SYNOPSIS
    Checks if write permissions are required to create new management groups

.DESCRIPTION
    This test ensures that only users with explicit write access can create new management groups.
    This is important to prevent unauthorized creation of management groups which could lead to security risks.

.EXAMPLE
    Test-MtManagementGroupWriteRequirement

    Returns true if write permissions are required for creating new management groups.

.LINK
    https://maester.dev/docs/commands/Test-MtManagementGroupWriteRequirement
#>
function Test-MtManagementGroupWriteRequirement {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Azure)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    # Get all management groups in the tenant and filter the tenant root management group by id
    $rootManagementGroup = Get-MtAzureManagementGroup | Where-Object { $_.id -match "$($_.properties.tenantid)$" }

    if (!$rootManagementGroup) {
        Write-Verbose "Tenant Root Group not found in management groups."
        Add-MtTestResultDetail -SkippedBecause "Custom" -SkippedCustomReason "Tenant Root Group not found"
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
        if ($testResult) {
            $testResultMarkdown = "Write permissions are required for creating new management groups."
        } else {
            $testResultMarkdown = "Write permissions are NOT required for creating new management groups. Anyone in the tenant may create them."
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
