<#
 .Synopsis
    Checks if any conditional access policy explicitly includes Azure DevOps

 .Description
    Azure DevOps will no longer rely on the Azure Resource Manager (ARM) resource during sign-in or token refresh flows.
    Organizations must update their Conditional Access policies to explicitly include Azure DevOps to maintain secure access.

  .Example
    Test-MtCaAzureDevOps

.LINK
    https://maester.dev/docs/commands/Test-MtCaAzureDevOps
#>
function Test-MtCaAzureDevOps {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Allow')]
    param ()

    Write-Verbose "Checking for Conditional Access policies that explicitly include Azure DevOps..."

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
    $policiesResult = New-Object System.Collections.ArrayList
    $result = $false

    $azureDevOpsAppId = '499b84ac-1321-427f-aa17-267ca6975798'
    foreach ($policy in $policies) {
        if ( $azureDevOpsAppId -in ($policy.conditions.applications.includeApplications) ) {
            $result = $true
            $policiesResult.Add($policy) | Out-Null
        }
    }
    if (($policiesResult | Measure-Object).Count -ne 0) {
        $testResult = "Well done! There are conditional access policies that explicitly include Azure DevOps.`n`n%TestResult%"
        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess
    } else {
        $testResult = "There are no conditional access policies that explicitly target Azure DevOps."
        Add-MtTestResultDetail -Result $testResult
    }
    return $result
}