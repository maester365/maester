<#
.SYNOPSIS
    Checks if a policy is enabled requiring a managed device for registration

.DESCRIPTION
    Managed Devices SHOULD be required to register MFA.

.EXAMPLE
    Test-MtCisaManagedDeviceRegistration

    Returns true if at least one policy requires MFA for registration

.LINK
    https://maester.dev/docs/commands/Test-MtCisaManagedDeviceRegistration
#>
function Test-MtCisaManagedDeviceRegistration {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Do not check if Hybrid Joined devices are accepted.
        [switch]$SkipHybridJoinCheck
    )

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    if($EntraIDPlan -eq "Free"){
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    $result = Get-MtConditionalAccessPolicy

    if($SkipHybridJoinCheck){
        $policies = $result | Where-Object {`
            $_.state -eq "enabled" -and `
            $_.conditions.applications.includeUserActions -contains "urn:user:registersecurityinfo" -and `
            $_.conditions.users.includeUsers -contains "All" -and `
            $_.grantControls.builtInControls -contains "compliantDevice" }
    }else{
        $policies = $result | Where-Object {`
            $_.state -eq "enabled" -and `
            $_.conditions.applications.includeUserActions -contains "urn:user:registersecurityinfo" -and `
            $_.conditions.users.includeUsers -contains "All" -and `
            $_.grantControls.builtInControls -contains "compliantDevice" -and `
            $_.grantControls.builtInControls -contains "domainJoinedDevice" -and `
            $_.grantControls.operator -eq "OR" }
    }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult -and $SkipHybridJoinCheck) {
        $testResultMarkdown = "Well done, your security posture is more than CISA's recommended control. Your tenant has one or more policies that require a compliant device for registration:`n`n%TestResult%"
    } elseif ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require a compliant or domain joined device for registration:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that require managed devices for registration."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}