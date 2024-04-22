<#
.SYNOPSIS
    Checks if Risk Based Policies - MS.AAD.2.1v1 is set to 'blocked'

.DESCRIPTION

    Users detected as high risk SHALL be blocked.

    Queries /identity/conditionalAccess/policies
    and returns the result of
     (graph/identity/conditionalAccess/policies?$filter=(state eq 'enabled') and (grantControls/builtInControls/any(c:c eq 'block')) and (conditions/applications/includeApplications/any(c:c eq 'All')) and (conditions/userRiskLevels/any(c:c eq 'high')) and (conditions/users/includeUsers/any(c:c eq 'All'))&$count=true).'@odata.count' -ge 1

.EXAMPLE
    Test-MtCisaBlockHighRisk

    Returns the result of (graph.microsoft.com/v1.0/identity/conditionalAccess/policies?$filter=(state eq 'enabled') and (grantControls/builtInControls/any(c:c eq 'block')) and (conditions/applications/includeApplications/any(c:c eq 'All')) and (conditions/userRiskLevels/any(c:c eq 'high')) and (conditions/users/includeUsers/any(c:c eq 'All'))&$count=true).'@odata.count' -ge 1
#>

Function Test-MtCisaBlockHighRisk {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $blockPolicies = $result | Where-Object {`
            $_.state -eq "enabled" -and `
            $_.grantControls.builtInControls -contains "block" -and `
            $_.applications.includeApplications -contains "all" -and `
            $_.conditions.userRiskLevels -contains "high" -and `
            $_.conditions.users.includeUsers -contains "All" }

    $testResult = $blockPolicies.Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Your tenant has one or more policies that block high risk user logins:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that block high risk user logins."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $blockPolicies

    return $testResult
}