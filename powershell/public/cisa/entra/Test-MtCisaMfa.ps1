<#
.SYNOPSIS
    Checks if Conditional Access Policy requiring MFA is enabled

.DESCRIPTION
    If phishing-resistant MFA has not been enforced, an alternative MFA method SHALL be enforced for all users

.EXAMPLE
    Test-MtCisaMfa

    Returns true if at least one policy requires MFA

.LINK
    https://maester.dev/docs/commands/Test-MtCisaMfa
#>
function Test-MtCisaMfa {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    if($EntraIDPlan -eq "Free"){
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }elseif(Test-MtCisaPhishResistant){
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Test-MtCisaPhishResistant Passed"
        return $null
    }

    $result = Get-MtConditionalAccessPolicy

    $policies = $result | Where-Object {`
        $_.state -eq "enabled" -and `
        $_.conditions.applications.includeApplications -contains "All" -and `
        $_.conditions.users.includeUsers -contains "All" -and `
        $_.grantControls.builtInControls -contains "mfa" }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require MFA:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that require MFA."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}