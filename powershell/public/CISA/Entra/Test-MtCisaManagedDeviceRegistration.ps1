<#
.SYNOPSIS
    Checks if a policy is enabled requiring a managed device for registration

.DESCRIPTION

    Managed Devices SHOULD be required to register MFA.

.EXAMPLE
    Test-MtCisaManagedDeviceRegistration

    Returns true if at least one policy requires MFA for registration
#>

Function Test-MtCisaManagedDeviceRegistration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Get-MtConditionalAccessPolicy

    $policies = $result | Where-Object {`
        $_.state -eq "enabled" -and `
        $_.conditions.users.includeUsers -contains "All" -and `
        $_.conditions.applications.includeUserActions -contains "urn:user:registersecurityinfo" -and `
        $_.grantControls.builtInControls -contains "compliantDevice" -and `
        $_.grantControls.builtInControls -contains "domainJoinedDevice" -and `
        $_.grantControls.operator -eq "OR" }

    $testResult = $policies.Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require managed devices for registration:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that requires managed devices for registration."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}