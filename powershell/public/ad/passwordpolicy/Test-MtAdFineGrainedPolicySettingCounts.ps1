function Test-MtAdFineGrainedPolicySettingCounts {
    <#
    .SYNOPSIS
    Provides a detailed breakdown of settings across all fine-grained password policies.

    .DESCRIPTION
    This test retrieves all fine-grained password policies and provides a detailed breakdown
    of the settings configured in each policy. This helps administrators understand exactly
    what security controls are applied to different user populations.

    .EXAMPLE
    Test-MtAdFineGrainedPolicySettingCounts

    Returns $true if fine-grained password policy data is accessible, $false otherwise.
    The test result includes detailed settings for each policy.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdFineGrainedPolicySettingCounts
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdFineGrainedPolicySettingCounts"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    # Get fine-grained password policies
    $fgppPolicies = $adState.FineGrainedPasswordPolicies
    $policyCount = ($fgppPolicies | Measure-Object).Count

    # Test passes if we successfully retrieved the policies
    $testResult = $null -ne $fgppPolicies

    # Generate markdown results
    if ($testResult) {
        if ($policyCount -gt 0) {
            $result = "| Policy Name | Min Length | Max Age (Days) | History | Complexity | Lockout Threshold |" + "`n"
            $result += "| --- | --- | --- | --- | --- | --- |" + "`n"

            foreach ($policy in $fgppPolicies) {
                $name = $policy.Name
                $minLength = $policy.MinPwdLength
                $maxAgeDays = $policy.MaxPwdAge.Days
                $history = $policy.PwdHistoryLength
                $complexity = if ($policy.PwdProperties) { "Yes" } else { "No" }
                $lockout = $policy.LockoutThreshold

                $result += "| $name | $minLength | $maxAgeDays | $history | $complexity | $lockout |" + "`n"
            }

            $recommendation = "Fine-grained password policy settings breakdown across $policyCount policies. Review to ensure appropriate security levels for different user populations."
        } else {
            $result = "| Metric | Value |" + "`n"
            $result += "| --- | --- |" + "`n"
            $result += "| Fine-Grained Password Policies | 0 |" + "`n"

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
