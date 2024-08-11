<#
.SYNOPSIS
    Checks if Conditional Access Policy using Phishing-Resistant Authentication Strengths is enabled

.DESCRIPTION
    Phishing-resistant MFA SHALL be enforced for all users

.EXAMPLE
    Test-MtCisaPhishResistant

    Returns true if at least one policy is set to use the built-in phishing resistant authentication strengths

.LINK
    https://maester.dev/docs/commands/Test-MtCisaPhishResistant
#>
function Test-MtCisaPhishResistant {
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
    }

    $result = Get-MtConditionalAccessPolicy

    $policies = $result | Where-Object {`
        $_.state -eq "enabled" -and `
        $_.conditions.applications.includeApplications -contains "All" -and `
        $_.conditions.users.includeUsers -contains "All" -and `
        $_.grantControls.authenticationStrength.displayName -eq "Phishing-resistant MFA" }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require Phishing Resistant Authentication Strengths :`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that require Phishing Resistant Authentication Strengths."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}