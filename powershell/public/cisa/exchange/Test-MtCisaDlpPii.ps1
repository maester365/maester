<#
.SYNOPSIS
    Checks state of DLP for EXO

.DESCRIPTION
    The DLP solution SHALL protect personally identifiable information (PII) and sensitive information, as defined by the agency.

.EXAMPLE
    Test-MtCisaDlpPii

    Returns true if

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDlpPii
#>
function Test-MtCisaDlpPii {
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

    $rules = $resultPolicies | ForEach-Object {
        Get-MtExo -Request DlpComplianceRule
    }

    $resultRules = $rules | Where-Object {`
        -not $_.Disabled -and `
        $_.Mode -eq "Enforce" -and `
        $_.BlockAccess -and `
        $_.BlockAccessScope -eq "All" -and `
        $_.NotifyPolicyTipDisplayOption -eq "Tip" -and `
        $_.AdvancedRule -like "*50b8b56b-4ef8-44c2-a924-03374f5831ce*" # All Full Names Sensitive Info Type
    }

    $testResult = ($resultRules | Measure-Object).Count -ge 1

    $portalLink = "https://purview.microsoft.com/datalossprevention/policies"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [Purview Data Loss Prevention Policies]($portalLink) enabled with the Sensitive Info Type of All Full Names.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [Purview Data Loss Prevention Policies]($portalLink) enabled with the Sensitive Info Type of All Full Names.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Status | Policy | Rule |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($item in ($rules | Sort-Object -Property ParentPolicyName,Name)) {
        $itemResult = $failResult
        if($item.Guid -in $resultRules.Guid){
            $itemResult = $passResult
        }
        $result += "| $($itemResult) | $($item.ParentPolicyName) | $($item.Name) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}