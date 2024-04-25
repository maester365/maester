<#
.SYNOPSIS
    Checks if User Risk Based Policies - MS.AAD.2.1 is set to 'blocked'

.DESCRIPTION

    Users detected as high risk SHALL be blocked.

.EXAMPLE
    Test-MtCisaBlockHighRiskUser

    Returns true if at least one policy is set to block high risk users.
#>

Function Test-MtCisaBlockHighRiskUser {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Get-MtConditionalAccessPolicy

    $blockPolicies = $result | Where-Object {`
        $_.state -eq "enabled" -and `
        $_.grantControls.builtInControls -contains "block" -and `
        $_.conditions.applications.includeApplications -contains "all" -and `
        $_.conditions.userRiskLevels -contains "high" -and `
        $_.conditions.users.includeUsers -contains "All" }

    $testResult = $blockPolicies.Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that block high risk users :`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that block high risk users."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $blockPolicies

    return $testResult
}