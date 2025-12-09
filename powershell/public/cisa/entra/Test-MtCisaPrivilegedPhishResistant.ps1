<#
.SYNOPSIS
    Checks if Conditional Access Policy requiring phishing resistant authentication methods for privileged roles is enabled

.DESCRIPTION
    Phishing-resistant MFA SHALL be required for highly privileged roles.

.EXAMPLE
    Test-MtCisaPrivilegedPhishResistant

    Returns true if at least one policy requires phishing resistant methods for the specific roles

.LINK
    https://maester.dev/docs/commands/Test-MtCisaPrivilegedPhishResistant
#>
function Test-MtCisaPrivilegedPhishResistant {
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

    $highlyPrivilegedRoles = Get-MtRole -CisaHighlyPrivilegedRoles

    $result = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    #Hacky approach to do validation of all objects
    $policies = $result | Where-Object {`
        $_.conditions.applications.includeApplications -contains "All" -and `
        $_.grantControls.authenticationStrength.displayName -eq "Phishing-resistant MFA" -and `
        ($_.conditions.users.includeRoles|Sort-Object) -join "," -like "*$(($highlyPrivilegedRoles.id|Sort-Object) -join "*")*" }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require phishing resistant MFA for highly privileged users:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that require phishing resistant MFA for highly privileged users."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}