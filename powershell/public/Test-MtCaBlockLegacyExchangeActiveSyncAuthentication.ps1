<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy that blocks legacy authentication for Exchange Active Sync authentication.

 .Description
    Legacy authentication is an unsecure method to authenticate. This function checks if the tenant has at least one
    conditional access policy that blocks legacy authentication.

  Learn more:
  https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy

 .Example
  Test-MtCaBlockLegacyExchangeActiveSyncAuthentication
#>

Function Test-MtCaBlockLegacyExchangeActiveSyncAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $result = $false
    foreach ($policy in $policies) {
        if ( $policy.grantcontrols.builtincontrols -contains 'block' `
                -and "exchangeActiveSync" -in $policy.conditions.clientAppTypes `
                -and $policy.conditions.applications.includeApplications -eq "00000002-0000-0ff1-ce00-000000000000" `
                -and $policy.conditions.users.includeUsers -eq "All" `
        ) {
            $result = $true
            $currentresult = $true
        } else {
            $currentresult = $false
        }
        Write-Verbose "$($policy.displayName) - $currentresult"
    }

    return $result
}