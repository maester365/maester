function Test-MtCisWeakAuthenticationMethodsDisabled {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -DisableCache

        Write-Verbose 'Executing checks'
        $checkSms = ($settings.authenticationMethodConfigurations | Where-Object { $_.id -eq "Sms" }).State -eq "disabled"
        $checkVoice = ($settings.authenticationMethodConfigurations | Where-Object { $_.id -eq "Voice" }).State -eq "disabled"
        $checkEmail = ($settings.authenticationMethodConfigurations | Where-Object { $_.id -eq "Email" }).State -eq "disabled"

        $testResult = $checkSms -eq $true -and $checkVoice -eq $true -and $checkEmail -eq $true

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenants settings matches CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenants settings does not matches CIS recommendations.`n`n%TestResult%"
        }

        $resultMd = "| Authentication method | Result |`n"
        $resultMd += "| --- | --- |`n"

        if ($checkSms) {
            $checkSmsResult = '✅ Pass'
        } else {
            $checkSmsResult = '❌ Fail'
        }

        if ($checkVoice) {
            $checkVoiceResult = '✅ Pass'
        } else {
            $checkVoiceResult = '❌ Fail'
        }

        if ($checkEmail) {
            $checkEmailResult = '✅ Pass'
        } else {
            $checkEmailResult = '❌ Fail'
        }

        $resultMd += "| SMS | $checkSmsResult |`n"
        $resultMd += "| Voice call | $checkVoiceResult |`n"
        $resultMd += "| Email OTP | $checkEmailResult |`n"

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}