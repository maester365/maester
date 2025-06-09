<#
.SYNOPSIS
    Checks if Baseline Policies Legacy Authentication - MS.AAD.1.1v1 is set to 'blocked'

.DESCRIPTION
    Legacy authentication SHALL be blocked.

.EXAMPLE
    Test-MtCisaBlockLegacyAuth

    Returns true if one or more CA policies exist that block legacy authentication.

.LINK
    https://maester.dev/docs/commands/Test-MtCisaBlockLegacyAuth
#>
function Test-MtCisaBlockLegacyAuth {
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

    $result = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $blockOther = $result | Where-Object {
        $_.grantControls.builtInControls -contains "block" -and
        $_.conditions.clientAppTypes -contains "other" -and
        $_.conditions.users.includeUsers -contains "All"
    }

    $blockExchangeActiveSync = $result | Where-Object {
        $_.grantControls.builtInControls -contains "block" -and
        $_.conditions.clientAppTypes -contains "exchangeActiveSync" -and
        $_.conditions.users.includeUsers -contains "All"
    }

    if (($blockOther | Measure-Object).Count -ge 1 -and ($blockExchangeActiveSync | Measure-Object).Count -ge 1) {
        $blockPolicies = @($blockOther) + @($blockExchangeActiveSync)  | Sort-Object id -Unique
    }

    $testResult = ($blockPolicies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Your tenant has one or more policies that block legacy authentication:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant lacks sufficient conditional access policies that block legacy authentication."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $blockPolicies

    return $testResult
}