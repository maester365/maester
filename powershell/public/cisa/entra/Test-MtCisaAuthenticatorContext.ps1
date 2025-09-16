<#
.SYNOPSIS
    Checks if the Authentication Methods policy for Microsoft Authenticator is set appropriately

.DESCRIPTION
    If Microsoft Authenticator is enabled, it SHALL be configured to show login context information.

.EXAMPLE
    Test-MtCisaAuthenticatorContext

    Returns true if the Authentication Methods policy for Microsoft Authenticator is set appropriately

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAuthenticatorContext
#>
function Test-MtCisaAuthenticatorContext {
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

    $authenticatorPolicy = $result | Where-Object {`
        $_.id -eq "MicrosoftAuthenticator" }

    $testResult = (($policies|Measure-Object).Count -ge 1)

    $link = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity"
    $resultFail = "❌ Fail"
    $resultPass = "✅ Pass"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has the [Authentication Methods]($link) policy for Microsoft Authenticator set appropriately.`n`n"
    } else {
        $testResultMarkdown = "Your tenant does not have the [Authentication Methods]($link) policy for Microsoft Authenticator set appropriately or migration to Authentication Methods is not complete.`n`n"
    }

    $checks = @{
        MethodEnabled    = if($authenticatorPolicy.state -eq "enabled"){$resultPass}else{$resultFail}
        MethodTarget     = if($authenticatorPolicy.includeTargets.Id -contains "all_users"){$resultPass}else{$resultFail}
        OtpDisabled      = if(-not $authenticatorPolicy.isSoftwareOathEnabled){$resultPass}else{$resultFail}
        ContextEnabled   = if($authenticatorPolicy.featureSettings.displayAppInformationRequiredState.state -eq "enabled"){$resultPass}else{$resultFail}
        ContextTarget    = if($authenticatorPolicy.featureSettings.displayAppInformationRequiredState.includeTarget.id -contains "all_users"){$resultPass}else{$resultFail}
        LocationEnabled  = if($authenticatorPolicy.featureSettings.displayLocationInformationRequiredState.state -eq "enabled"){$resultPass}else{$resultFail}
        LocationTarget   = if($authenticatorPolicy.featureSettings.displayLocationInformationRequiredState.includeTarget.id -contains "all_users"){$resultPass}else{$resultFail}
    }

    $testResultMarkdown += "| Setting | Result |`n"
    $testResultMarkdown += "| --- | --- |`n"
    $testResultMarkdown += "| Microsoft Authenticator state | $($checks.MethodEnabled) |`n"
    $testResultMarkdown += "| Included Targets | $($checks.MethodTarget) |`n"
    $testResultMarkdown += "| Allow use of Microsoft Authenticator OTP set to *No* | $($checks.OtpDisabled) |`n"
    $testResultMarkdown += "| Show application name in push and passwordless notifications status | $($checks.ContextEnabled) | `n"
    $testResultMarkdown += "| Show application name in push and passwordless notifications included target | $($checks.ContextTarget) | `n"
    $testResultMarkdown += "| Show geographic location in push and passwordless notifications status | $($checks.LocationEnabled) | `n"
    $testResultMarkdown += "| Show geographic location in push and passwordless notifications included target | $($checks.LocationTarget) | `n"

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}