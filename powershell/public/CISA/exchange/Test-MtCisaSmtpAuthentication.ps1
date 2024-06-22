<#
.SYNOPSIS
    Checks state of SMTP AuthN

.DESCRIPTION

    SMTP AUTH SHALL be disabled.

.EXAMPLE
    Test-MtCisaSmtpAuthentication

    Returns true if SMTP AuthN is disabled
#>

Function Test-MtCisaSmtpAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $config = Get-TransportConfig

    $testResult = $config.SmtpClientAuthenticationDisabled

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has SMTP Authentication disabled.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have SMTP Authentication disabled.`n`n%TestResult%"
    }

    $portalLink = "https://admin.exchange.microsoft.com/#/settings"
    $pass = "✅ Pass"
    $fail = "❌ Fail"
    $desc = "[Turn off SMTP AUTH protocol for your organization]($portalLink)"
    if($testResult){
        $result = "$pass | $desc`n"
    }else{
        $result = "$fail | $desc`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}