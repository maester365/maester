<#
.SYNOPSIS
    Checks if Baseline Policies Legacy Authentication - MS.AAD.1.1v1 is set to 'blocked'

.DESCRIPTION

    Legacy authentication SHALL be blocked.

    Queries /identity/conditionalAccess/policies
    and returns the result of
     (graph/identity/conditionalAccess/policies?$filter=(state eq 'enabled') and (grantControls/builtInControls/any(c:c eq 'block')) and (conditions/clientAppTypes/any(c:c eq 'exchangeActiveSync')) and (conditions/clientAppTypes/any(c:c eq 'other')) and (conditions/users/includeUsers/any(c:c eq 'All'))&$count=true).'@odata.count' -eq 1

.EXAMPLE
    Test-MtCisaLegacyAuth

    Returns the result of (graph.microsoft.com/v1.0/identity/conditionalAccess/policies?$filter=(state eq 'enabled') and (grantControls/builtInControls/any(c:c eq 'block')) and (conditions/clientAppTypes/any(c:c eq 'exchangeActiveSync')) and (conditions/clientAppTypes/any(c:c eq 'other')) and (conditions/users/includeUsers/any(c:c eq 'All'))&$count=true).'@odata.count' -eq 1
#>

Function Test-MtCisaLegacyAuth {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Get-MtConditionalAccessPolicy

    $tenantValue = ($result|Where-Object {`
        $_.state -eq "enabled" -and `
        $_.grantControls.builtInControls -contains "block" -and `
        $_.conditions.clientAppTypes -contains "exchangeActiveSync" -and `
        $_.conditions.clientAppTypes -contains "other" -and `
        $_.conditions.users.includeUsers -contains "All"}).count
    $testResult = $tenantValue -eq 1

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **1** for **identity/conditionalAccess/policies**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **1** for **identity/conditionalAccess/policies**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}