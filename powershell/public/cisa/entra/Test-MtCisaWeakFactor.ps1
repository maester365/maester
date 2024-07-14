<#
.SYNOPSIS
    Checks if weak Authentication Methods are disabled

.DESCRIPTION

    The authentication methods SMS, Voice Call, and Email One-Time Passcode (OTP) SHALL be disabled.

.EXAMPLE
    Test-MtCisaWeakFactor

    Returns true if weak Authentication Methods are disabled
#>

Function Test-MtCisaWeakFactor {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $weakFactors = @(
        "Sms",
        "Voice",
        "Email"
    )

    $isMethodsMigrationComplete = Test-MtCisaMethodsMigration

    $result = Get-MtAuthenticationMethodPolicyConfig

    $weakAuthMethods = $result | Where-Object { $_.id -in $weakFactors }

    $enabledWeakMethods = $weakAuthMethods | Where-Object { $_.state -eq "enabled" }

    $testResult = (($enabledWeakMethods|Measure-Object).Count -eq 0) -and $isMethodsMigrationComplete

    if ($testResult) {
        $testResultMarkdown = "Well done. All weak authentication methods are disabled in your tenant.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "One or more weak methods are enabled in your tenant, or migration to Authentication Methods is incomplete.`n`n%TestResult%"
    }

    # Auth method does not support deep links.
    $authMethodsLink = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods"
    $migrationResult = "❌ Fail"
    if($isMethodsMigrationComplete){$migrationResult = "✅ Pass"}
    $result = "[Authentication Methods]($authMethodsLink) Migration Complete: $migrationResult`n`n"
    $result += "| Authentication Method | State | Test Result |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($item in $weakAuthMethods) {
        $methodResult = "✅ Pass"
        if ($item.state -eq "enabled") {
            $methodResult = "❌ Fail"
        }
        $result += "| [$($item.id)]($authMethodsLink) | $($item.state) | $($methodResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}