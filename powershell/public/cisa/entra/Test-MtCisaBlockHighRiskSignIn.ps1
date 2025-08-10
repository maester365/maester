<#
.SYNOPSIS
    Checks if Sign-In Risk Based Policies - MS.AAD.2.3 is set to 'blocked'

.DESCRIPTION
    Sign-ins detected as high risk SHALL be blocked.

.EXAMPLE
    Test-MtCisaBlockHighRiskSignIn

    Returns true if at least one policy is set to block high risk sign-ins.

.LINK
    https://maester.dev/docs/commands/Test-MtCisaBlockHighRiskSignIn
#>
function Test-MtCisaBlockHighRiskSignIn {
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

    $result = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $blockPolicies = $result | Where-Object {`
        $_.grantControls.builtInControls -contains "block" -and `
        $_.conditions.applications.includeApplications -contains "all" -and `
        $_.conditions.signInRiskLevels -contains "high" -and `
        $_.conditions.users.includeUsers -contains "All" }

    $testResult = ($blockPolicies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that block high risk sign-ins.`n`n"
    } else {
        $testResultMarkdown = "Your tenant does not have any conditional access policies that block high risk sign-ins.`n`n"
    }

    $checks = @{
        EnabledCount                            = ($result|Measure-Object).Count
        BlockCount                              = (($result|Where-Object {$_.grantControls.builtInControls -contains "block"})|Measure-Object).Count
        BlockAllAppsCount                       = (($result|Where-Object {$_.grantControls.builtInControls -contains "block" -and $_.conditions.applications.includeApplications -contains "all"})|Measure-Object).Count
        BlockAllAppsSignInRiskHighCount         = (($result|Where-Object {$_.grantControls.builtInControls -contains "block" -and $_.conditions.applications.includeApplications -contains "all" -and $_.conditions.signInRiskLevels -contains "high"})|Measure-Object).Count
        BlockAllAppsSignInRiskHighAllUsersCount = (($result|Where-Object {$_.grantControls.builtInControls -contains "block" -and $_.conditions.applications.includeApplications -contains "all" -and $_.conditions.signInRiskLevels -contains "high" -and $_.conditions.users.includeUsers -contains "All"})|Measure-Object).Count
    }

    $testResultMarkdown += "| Criteria | Count of Policies |`n"
    $testResultMarkdown += "| --- | --- |`n"
    $testResultMarkdown += "| Enabled | $($checks.EnabledCount) |`n"
    $testResultMarkdown += "| Enabled & Blocking | $($checks.BlockCount) |`n"
    $testResultMarkdown += "| Enabled, Blocking, & All Apps | $($checks.BlockAllAppsCount) |`n"
    $testResultMarkdown += "| Enabled, Blocking, All Apps, & Sign In Risk High | $($checks.BlockAllAppsSignInRiskHighCount) |`n"
    $testResultMarkdown += "| Enabled, Blocking, All Apps, Sign In Risk High, & All Users | $($checks.BlockAllAppsSignInRiskHighAllUsersCount) |`n`n"

    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $blockPolicies

    return $testResult
}
