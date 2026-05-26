function Test-MtCisaAuthenticatorContextCompliance {
    <#
    .SYNOPSIS
    Checks if the Authentication Methods policy for Microsoft Authenticator is set appropriately

    .DESCRIPTION
    If Microsoft Authenticator is enabled, it SHALL be configured to show login context information.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaAuthenticatorContextCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    if($EntraIDPlan -eq "Free"){
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


    return $testResult

}
