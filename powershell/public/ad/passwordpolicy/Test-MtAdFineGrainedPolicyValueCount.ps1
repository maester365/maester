function Test-MtAdFineGrainedPolicyValueCount {
    <#
    .SYNOPSIS
    Analyzes distinct values across all fine-grained password policies.

    .DESCRIPTION
    This test retrieves all fine-grained password policies and counts the distinct values
    configured across them. This provides insight into the variety of password policy
    settings in use and helps identify inconsistencies or gaps in policy coverage.

    .EXAMPLE
    Test-MtAdFineGrainedPolicyValueCount

    Returns $true if fine-grained password policy data is accessible, $false otherwise.
    The test result includes counts of distinct values across policies.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdFineGrainedPolicyValueCount
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

    # Get fine-grained password policies
    try {
        $fgppPolicies = Get-ADFineGrainedPasswordPolicy -Filter * -ErrorAction Stop
        $policyCount = ($fgppPolicies | Measure-Object).Count
    } catch {
        Write-Error "Failed to retrieve fine-grained password policies: $($_.Exception.Message)"
        return $null
    }

    # Test passes if we successfully retrieved the policies
    $testResult = $null -ne $fgppPolicies

    # Generate markdown results
    if ($testResult) {
        if ($policyCount -gt 0) {
            # Count distinct values across all policies
            $distinctMinLength = ($fgppPolicies | Select-Object -ExpandProperty MinPasswordLength -Unique | Measure-Object).Count
            $distinctMaxAge = ($fgppPolicies | Select-Object -ExpandProperty MaxPasswordAge -Unique | Measure-Object).Count
            $distinctHistory = ($fgppPolicies | Select-Object -ExpandProperty PasswordHistoryCount -Unique | Measure-Object).Count
            $distinctComplexity = ($fgppPolicies | Select-Object -ExpandProperty ComplexityEnabled -Unique | Measure-Object).Count
            $distinctLockoutThreshold = ($fgppPolicies | Select-Object -ExpandProperty LockoutThreshold -Unique | Measure-Object).Count

            $result = "| Metric | Distinct Values |`n"
            $result += "| --- | --- |`n"
            $result += "| Total FGPPs | $policyCount |`n"
            $result += "| Min Password Length Values | $distinctMinLength |`n"
            $result += "| Max Password Age Values | $distinctMaxAge |`n"
            $result += "| Password History Values | $distinctHistory |`n"
            $result += "| Complexity Settings | $distinctComplexity |`n"
            $result += "| Lockout Threshold Values | $distinctLockoutThreshold |`n"

            $recommendation = "Fine-grained password policies show variation across $policyCount policies. Review these settings to ensure appropriate security levels for different user populations."
        } else {
            $result = "| Metric | Value |`n"
            $result += "| --- | --- |`n"
            $result += "| Fine-Grained Password Policies | 0 |`n"

            $recommendation = "No fine-grained password policies are configured. The domain uses only the default domain password policy."
        }

        $testResultMarkdown = "$recommendation`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve fine-grained password policies. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


