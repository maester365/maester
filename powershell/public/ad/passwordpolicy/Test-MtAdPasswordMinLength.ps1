function Test-MtAdPasswordMinLength {
    <#
    .SYNOPSIS
    Checks the minimum password length configured in the default domain password policy.

    .DESCRIPTION
    This test retrieves the minimum password length from the default domain password policy.
    Minimum password length is one of the most effective controls against brute-force and
    dictionary attacks. Longer passwords exponentially increase the time required to crack them.

    .EXAMPLE
    Test-MtAdPasswordMinLength

    Returns $true if the password policy is accessible, $false otherwise.
    The test result includes the configured minimum password length.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdPasswordMinLength
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
        $minPasswordLength = $passwordPolicy.MinPasswordLength
    } catch {
        Write-Error "Failed to retrieve password policy: $($_.Exception.Message)"
        return $null
    }

    # Test passes if we successfully retrieved the password policy
    $testResult = $null -ne $minPasswordLength

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Minimum Password Length | $minPasswordLength characters |`n"
        $result += "| Recommended Minimum | 14 characters |`n"

        $recommendation = if ($minPasswordLength -ge 14) {
            "✅ Minimum password length meets or exceeds the recommended minimum of 14 characters."
        } else {
            "⚠️ Minimum password length is below the recommended 14 characters. Consider increasing this to improve resistance against brute-force attacks."
        }

        $testResultMarkdown = "$recommendation`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve the default domain password policy. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}

