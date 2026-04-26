function Test-MtAdAccountLockoutThreshold {
    <#
    .SYNOPSIS
    Checks the account lockout threshold configured in the default domain password policy.

    .DESCRIPTION
    This test retrieves the account lockout threshold from the default domain password policy.
    Lockout threshold determines how many failed logon attempts are allowed before an account
    is locked out. This is a critical defense against brute-force and dictionary attacks.

    .EXAMPLE
    Test-MtAdAccountLockoutThreshold

    Returns $true if the password policy is accessible, $false otherwise.
    The test result includes the configured lockout threshold.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdAccountLockoutThreshold
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    # Get the default domain password policy
    try {
        $passwordPolicy = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
        $lockoutThreshold = $passwordPolicy.LockoutThreshold
    } catch {
        Write-Error "Failed to retrieve password policy: $($_.Exception.Message)"
        return $null
    }

    # Test passes if we successfully retrieved the password policy
    $testResult = $null -ne $lockoutThreshold

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        if ($lockoutThreshold -eq 0) {
            $result += "| Lockout Threshold | Accounts never lock out |`n"
        } else {
            $result += "| Lockout Threshold | $lockoutThreshold failed attempts |`n"
        }
        $result += "| Recommended Maximum | 5 or fewer attempts |`n"

        $recommendation = if ($lockoutThreshold -eq 0) {
            "❌ Account lockout is disabled. This allows unlimited password attempts, making brute-force attacks trivial. Enable account lockout immediately."
        } elseif ($lockoutThreshold -le 5) {
            "✅ Lockout threshold is 5 or fewer attempts, providing good protection against brute-force attacks."
        } else {
            "⚠️ Lockout threshold exceeds 5 attempts. Consider reducing this to provide better protection against brute-force attacks while balancing usability."
        }

        $testResultMarkdown = "$recommendation`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve the default domain password policy. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



