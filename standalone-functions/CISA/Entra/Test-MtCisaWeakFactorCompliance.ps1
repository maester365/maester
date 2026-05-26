function Test-MtCisaWeakFactorCompliance {
    <#
    .SYNOPSIS
    Checks if weak Authentication Methods are disabled

    .DESCRIPTION
    The authentication methods SMS, Voice Call, and Email One-Time Passcode (OTP) SHALL be disabled.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaWeakFactorCompliance
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

    $weakFactors = @(
        "Sms",
        "Voice",
        "Email"
    )

    $result = Get-MtAuthenticationMethodPolicyConfig

    $weakAuthMethods = $result | Where-Object { $_.id -in $weakFactors }

    $enabledWeakMethods = $weakAuthMethods | Where-Object { $_.state -eq "enabled" }

    $testResult = (($enabledWeakMethods|Measure-Object).Count -eq 0)
    # Auth method does not support deep links.
    $authMethodsLink = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods"

    $result = "| Authentication Method | State | Test Result |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($item in $weakAuthMethods) {
        $methodResult = "✅ Pass"
        if ($item.state -eq "enabled") {
            $methodResult = "❌ Fail"
        }
        $result += "| [$($item.id)]($authMethodsLink) | $($item.state) | $($methodResult) |`n"
    }


    return $testResult

}
