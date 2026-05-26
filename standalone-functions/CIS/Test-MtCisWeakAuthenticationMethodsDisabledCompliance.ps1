function Test-MtCisWeakAuthenticationMethodsDisabledCompliance {
    <#
    .SYNOPSIS
    Checks if weak authentication methods (SMS, voice call, email OTP) are disabled in the tenant.

    .DESCRIPTION
    Weak authentication methods such as SMS, voice call, and email OTP should be disabled.
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisWeakAuthenticationMethodsDisabledCompliance
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

    try {
        Write-Verbose 'Getting settings...'
        $settings = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy' -DisableCache

        Write-Verbose 'Executing checks'
        $checkSms = ($settings.authenticationMethodConfigurations | Where-Object { $_.id -eq "Sms" }).State -eq "disabled"
        $checkVoice = ($settings.authenticationMethodConfigurations | Where-Object { $_.id -eq "Voice" }).State -eq "disabled"
        $checkEmail = ($settings.authenticationMethodConfigurations | Where-Object { $_.id -eq "Email" }).State -eq "disabled"

        $testResult = $checkSms -and $checkVoice -and $checkEmail
        if ($checkSms) {
            $checkSmsResult = '✅ Pass'
        }
        else {
            $checkSmsResult = '❌ Fail'
        }

        if ($checkVoice) {
            $checkVoiceResult = '✅ Pass'
        }
        else {
            $checkVoiceResult = '❌ Fail'
        }

        if ($checkEmail) {
            $checkEmailResult = '✅ Pass'
        }
        else {
            $checkEmailResult = '❌ Fail'
        }


        return $testResult
    }
    catch {
        return $null
    }

}
