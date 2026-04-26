function Test-MtAdFineGrainedPolicyCount {
    <#
    .SYNOPSIS
    Counts the number of fine-grained password policies configured in the domain.

    .DESCRIPTION
    This test retrieves and counts the fine-grained password policies (FGPP) configured
    in the Active Directory domain. Fine-grained password policies allow different
    password and account lockout policies to be applied to different sets of users
    or groups within the same domain, providing more granular security controls.

    .EXAMPLE
    Test-MtAdFineGrainedPolicyCount

    Returns $true if fine-grained password policy data is accessible, $false otherwise.
    The test result includes the count of configured FGPPs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdFineGrainedPolicyCount
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
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Fine-Grained Password Policies | $policyCount |`n"

        if ($policyCount -eq 0) {
            $recommendation = "ℹ️ No fine-grained password policies are configured. The domain uses the default domain password policy for all users. Consider implementing FGPPs for privileged accounts requiring stronger policies."
        } elseif ($policyCount -eq 1) {
            $recommendation = "ℹ️ One fine-grained password policy is configured. This allows different password requirements for specific users or groups."
        } else {
            $recommendation = "ℹ️ $policyCount fine-grained password policies are configured, providing granular password policy control across different user populations."
        }

        $testResultMarkdown = "$recommendation`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve fine-grained password policies. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



