<#
.SYNOPSIS
    Checks if weak Authentication Methods are disabled

.DESCRIPTION

    The authentication methods SMS, Voice Call, and Email One-Time Passcode (OTP) SHALL be disabled.

.EXAMPLE
    Test-MtCisaWeakFactors

    Returns true if weak Authentication Methods are disabled
#>

Function Test-MtCisaWeakFactors {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $weakFactors = @(
        "Sms",
        "Voice",
        "Email"
    )

    $result = Get-MtAuthenticationMethodPolicyConfig

    $policies = $result | Where-Object {`
        $_.id -in $weakFactors -and `
        $_.state -eq "enabled" }

    $testResult = $policies.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has SMS, Voice Call, and Email One-Time Passcode (OTP) authentication methods disabled:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have SMS, Voice Call, and Email One-Time Passcode (OTP) authentication methods disabled."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}