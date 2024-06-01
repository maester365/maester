<#
.SYNOPSIS
    Checks if Conditional Access Policy requiring managed device is enabled

.DESCRIPTION

    Managed devices SHOULD be required for authentication.

.EXAMPLE
    Test-MtCisaManagedDevice

    Returns true if at least one policy requires managed devices
#>

Function Test-MtCisaManagedDevice {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [switch]$SkipHybridJoinCheck
    )

    $result = Get-MtConditionalAccessPolicy

    if($SkipHybridJoinCheck){
        $policies = $result | Where-Object {`
            $_.state -eq "enabled" -and `
            $_.conditions.applications.includeApplications -contains "All" -and `
            $_.conditions.users.includeUsers -contains "All" -and `
            $_.grantControls.builtInControls -contains "compliantDevice" }
    }else{
        $policies = $result | Where-Object {`
            $_.state -eq "enabled" -and `
            $_.conditions.applications.includeApplications -contains "All" -and `
            $_.conditions.users.includeUsers -contains "All" -and `
            $_.grantControls.builtInControls -contains "compliantDevice" -and `
            $_.grantControls.builtInControls -contains "domainJoinedDevice" -and `
            $_.grantControls.operator -eq "OR" }
    }

    $testResult = $policies.Count -ge 1

    if ($testResult -and $SkipHybridJoinCheck) {
        $testResultMarkdown = "Well done, your security posture is more than CISA's recommended control. Your tenant has one or more policies that require a compliant device:`n`n%TestResult%"
    } elseif ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require a compliant or domain joined device:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that require managed devices."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}