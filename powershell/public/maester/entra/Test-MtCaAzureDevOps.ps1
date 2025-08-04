<#
 .Synopsis
    Checks if any conditional access policy explicitly includes Azure DevOps

 .Description
    Azure DevOps will no longer rely on the Azure Resource Manager (ARM) resource during sign-in or token refresh flows.
    Organizations must update their Conditional Access policies to explicitly include Azure DevOps to maintain secure access.

  .Example
    Test-MtCaAzureDevOps

.LINK
    https://maester.dev/docs/commands/
#>
function Test-MtCaAzureDevOps {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
    $policiesResult = New-Object System.Collections.ArrayList
    $result = $false

    foreach ($policy in $policies) {
        if ( "499b84ac-1321-427f-aa17-267ca6975798" -in ($policies.conditions.applications.includeApplications) ) {
            $result = $true
            $policiesResult.Add($policy) | Out-Null
        }
    }
    if (($policiesResult | Measure-Object).Count -ne 0) {
        $testResult = "Well done! There are conditional access policies that explicitly include Azure DevOps.`n`n%TestResult%"
        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess
    } else {
        $testResult = "There are no conditional access policies that explicitly include Azure DevOps.`n`n%TestResult%"
        Add-MtTestResultDetail -Result $testResult
    }
    return $result
}