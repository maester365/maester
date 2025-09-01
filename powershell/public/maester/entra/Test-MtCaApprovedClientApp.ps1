<#
 .Synopsis
    Checks if the tenant has no conditional access policy that requires an approved client app.

 .Description
    The approved client app grant is retiring in early March 2026.
    Organizations must transition all current Conditional Access policies that use only the require approved Client App grant control to Require Approved Client App or Application Protection Policy by March 2026.
    Additionally, for any new Conditional Access policy, only apply the Require application protection policy grant.
    After March 2026, Microsoft will stop enforcing require approved client app control, and it will be as if this grant isn't selected. Use the following steps before March 2026 to protect your organization’s data.
    Learn more:
    https://learn.microsoft.com/en-us/entra/identity/conditional-access/migrate-approved-client-app

  .Example
    Test-MtCaApprovedClientApp

.LINK
    https://maester.dev/docs/commands/Test-MtCaApprovedClientApp
#>
function Test-MtCaApprovedClientApp {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Write-Verbose "Checking for deprecated Approved Client App grant in Conditional Access policies..."
    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
    $policiesResult = New-Object System.Collections.ArrayList

    foreach ($policy in $policies) {
        if ( "approvedApplication" -in ($policy.grantControls.builtInControls) ) {
            $policiesResult.Add($policy) | Out-Null
        }
    }

    # There should be no conditional access policies using the deprecated Approved Client App grant.
    $result = ($policiesResult | Measure-Object).Count -eq 0

    if ($result) {
        $testResult = "Well done! No conditional access use the deprecated Approved Client App grant."
        Add-MtTestResultDetail -Result $testResult
    } else {
        $testResult = "The following conditional access policies use the deprecated Approved Client App grant:`n`n%TestResult%"
        Add-MtTestResultDetail -Result $testResult -GraphObjects $policiesResult -GraphObjectType ConditionalAccess
    }
    return $result
}

