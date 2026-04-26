function Test-MtAdAccountLockoutDuration {
    <#
    .SYNOPSIS
    Checks the account lockout duration configured in the default domain password policy.

    .DESCRIPTION
    This test retrieves the account lockout duration from the default domain password policy.
    Lockout duration determines how long an account remains locked after exceeding the
    lockout threshold. An appropriate duration balances security (preventing brute-force
    attacks) with usability (not locking users out for excessive periods).

    .EXAMPLE
    Test-MtAdAccountLockoutDuration

    Returns $true if the password policy is accessible, $false otherwise.
    The test result includes the configured lockout duration in minutes.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdAccountLockoutDuration
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
        $lockoutDuration = $passwordPolicy.LockoutDuration
    } catch {
        Write-Error "Failed to retrieve password policy: $($_.Exception.Message)"
        return $null
    }

    # Test passes if we successfully retrieved the password policy
    $testResult = $null -ne $lockoutDuration

    # Generate markdown results
    if ($testResult) {
        $lockoutDurationMinutes = $lockoutDuration.TotalMinutes

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        if ($lockoutDurationMinutes -eq 0) {
            $result += "| Lockout Duration | Until administrator unlocks |`n"
        } else {
            $result += "| Lockout Duration | $([Math]::Round($lockoutDurationMinutes, 0)) minutes |`n"
        }
        $result += "| Recommended Minimum | 30 minutes |`n"

        $recommendation = if ($lockoutDurationMinutes -eq 0) {
            "ℹ️ Accounts remain locked until manually unlocked by an administrator. This provides maximum security but requires administrative overhead."
        } elseif ($lockoutDurationMinutes -ge 30) {
            "✅ Lockout duration meets or exceeds the recommended minimum of 30 minutes."
        } else {
            "⚠️ Lockout duration is less than 30 minutes. Consider increasing this to provide better protection against brute-force attacks."
        }

        $testResultMarkdown = "$recommendation`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve the default domain password policy. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



