<#
.SYNOPSIS
    Checks state of DLP for EXO

.DESCRIPTION
    A DLP solution SHALL be used.

.EXAMPLE
    Test-MtCisaDlp

    Returns true if

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDlp
#>
function Test-MtCisaDlp {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }elseif($null -eq (Get-MtLicenseInformation -Product ExoDlp)){
        Add-MtTestResultDetail -SkippedBecause NotLicensedExoDlp
        return $null
    }

    $policies = Get-MtExo -Request DlpCompliancePolicy

    $resultPolicies = $policies | Where-Object {`
        $_.ExchangeLocation.DisplayName -contains "All" -and `
        $_.Workload -like "*Exchange*" -and `
        -not $_.IsSimulationPolicy -and `
        $_.Enabled
    }

    $testResult = ($resultPolicies | Measure-Object).Count -ge 1

    $portalLink = "https://purview.microsoft.com/datalossprevention/policies"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [Purview Data Loss Prevention Policies]($portalLink) enabled.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [Purview Data Loss Prevention Policies]($portalLink) enabled.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Name | Status | Description |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($item in ($policies | Where-Object {$_.ExchangeLocation.DisplayName -contains "All"}) | Sort-Object -Property name) {
        $itemResult = $failResult
        if($item.Guid -in $resultPolicies.Guid){
            $itemResult = $passResult
        }
        $result += "| $($item.name) | $($itemResult) | $($item.comment) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}