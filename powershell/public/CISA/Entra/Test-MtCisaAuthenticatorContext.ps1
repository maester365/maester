<#
.SYNOPSIS
    Checks if the Authentication Methods policy for Microsoft Authenticator is set appropriately

.DESCRIPTION

    If phishing-resistant MFA has not been enforced and Microsoft Authenticator is enabled, it SHALL be configured to show login context information

.EXAMPLE
    Test-MtCisaAuthenticatorContext

    Returns true if the Authentication Methods policy for Microsoft Authenticator is set appropriately
#>

Function Test-MtCisaAuthenticatorContext {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $result = Get-MtAuthenticationMethodPolicyConfig

    $policies = $result | Where-Object {`
        $_.id -eq "MicrosoftAuthenticator" -and `
        $_.state -eq "enabled" -and `
        $_.includeTargets.Id -contains "all_users" -and `
        $_.isSoftwareOathEnabled -eq $false -and `
        $_.featureSettings.displayAppInformationRequiredState.state -eq "enabled" -and `
        $_.featureSettings.displayAppInformationRequiredState.includeTarget.id -contains "all_users" -and `
        $_.featureSettings.displayLocationInformationRequiredState.state -eq "enabled" -and `
        $_.featureSettings.displayLocationInformationRequiredState.includeTarget.id -contains "all_users" }

    $testResult = ($policies|Measure-Object).Count -ge 1

    $link = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has the [Authentication Methods]($link) policy for Microsoft Authenticator set appropriately."
    } else {
        $testResultMarkdown = "Your tenant does not have the [Authentication Methods]($link) policy for Microsoft Authenticator set appropriately."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}