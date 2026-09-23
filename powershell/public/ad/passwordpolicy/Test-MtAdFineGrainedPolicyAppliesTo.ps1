function Test-MtAdFineGrainedPolicyAppliesTo {
    <#
    .SYNOPSIS
    Shows which users and groups each fine-grained password policy applies to.

    .DESCRIPTION
    This test retrieves all fine-grained password policies and shows which users and groups
    each policy applies to. This is critical for understanding the scope of each policy and
    ensuring that the right users have the appropriate password requirements.

    .EXAMPLE
    Test-MtAdFineGrainedPolicyAppliesTo

    Returns $true if fine-grained password policy data is accessible, $false otherwise.
    The test result includes the application targets for each policy.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdFineGrainedPolicyAppliesTo
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdFineGrainedPolicyAppliesTo"

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
            $result = ""

            foreach ($policy in $fgppPolicies) {
                $policyName = $policy.Name
                $appliesTo = $policy.MsDsPsoAppliesTo

                $result += "**Policy: $policyName**" + "`n" + "`n"

                if ($appliesTo -and $appliesTo.Count -gt 0) {
                    $result += "| Applies To | Type |" + "`n"
                    $result += "| --- | --- |" + "`n"

                    foreach ($target in $appliesTo) {
                        $object = $adState.Users | Where-Object { $_.DistinguishedName -eq $target } | Select-Object -First 1
                        $objectClass = 'user'
                        if ($null -eq $object) {
                            $object = $adState.Groups | Where-Object { $_.DistinguishedName -eq $target } | Select-Object -First 1
                            $objectClass = 'group'
                        }
                        if ($null -eq $object) {
                            $object = $adState.Computers | Where-Object { $_.DistinguishedName -eq $target } | Select-Object -First 1
                            $objectClass = 'computer'
                        }
                        if ($object) {
                            $objectName = $object.Name
                            $result += "| $objectName | $objectClass |" + "`n"
                        } else {
                            $result += "| $target | Unknown |" + "`n"
                        }
                    }
                    $result += "" + "`n"
                } else {
                    $result += "⚠️ This policy is not applied to any users or groups." + "`n" + "`n"
                }
            }

            $recommendation = "Fine-grained password policy application targets across $policyCount policies. Ensure policies are applied to the correct users and groups."
        } else {
            $result = "| Metric | Value |" + "`n"
            $result += "| --- | --- |" + "`n"
            $result += "| Fine-Grained Password Policies | 0 |" + "`n"

            $recommendation = "No fine-grained password policies are configured. The domain uses only the default domain password policy."
        }

        $testResultMarkdown = "$recommendation`n`n$result"
    } else {
        $testResultMarkdown = "Unable to retrieve fine-grained password policies. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
