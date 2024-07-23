<#
.SYNOPSIS
    Get details of authentication methods

.DESCRIPTION
    This function retrieves the configuration of authentication methods with specific state.

.EXAMPLE
    Get-MtAuthenticationMethodPolicyConfig -State Enabled

.LINK
    https://maester.dev/docs/commands/Get-MtAuthenticationMethodPolicyConfig
#>
function Get-MtAuthenticationMethodPolicyConfig {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Enabled", "Disabled")]
        # Only return methods in the spcecified state. Can be Enabled or Disabled.
        [string]$State
    )

    Write-Verbose -Message "Getting authenticationMethodConfigurations from Authentication Methods Policy."
    if ($State) {
        return (Invoke-MtGraphRequest -RelativeUri 'policies/authenticationMethodsPolicy' -ApiVersion beta).authenticationMethodConfigurations | where-object {$_.state -eq $state}
    } else {
        return (Invoke-MtGraphRequest -RelativeUri 'policies/authenticationMethodsPolicy' -ApiVersion beta).authenticationMethodConfigurations
    }
}