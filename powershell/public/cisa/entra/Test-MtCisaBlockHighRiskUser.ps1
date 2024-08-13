<#
.SYNOPSIS
    Checks if User Risk Based Policies - MS.AAD.2.1 is set to 'blocked'

.DESCRIPTION
    Users detected as high risk SHALL be blocked.

.EXAMPLE
    Test-MtCisaBlockHighRiskUser

    Returns true if at least one policy is set to block high risk users.

.LINK
    https://maester.dev/docs/commands/Test-MtCisaBlockHighRiskUser
#>
function Test-MtCisaBlockHighRiskUser {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    if($EntraIDPlan -ne "P2"){
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
    }

    $result = Get-MtConditionalAccessPolicy

    $blockPolicies = $result | Where-Object {`
        $_.state -eq "enabled" -and `
        $_.grantControls.builtInControls -contains "block" -and `
        $_.conditions.applications.includeApplications -contains "all" -and `
        $_.conditions.userRiskLevels -contains "high" -and `
        $_.conditions.users.includeUsers -contains "All" }

    $testResult = ($blockPolicies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that block high risk users :`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that block high risk users."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $blockPolicies

    return $testResult
}