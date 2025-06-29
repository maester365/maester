<#
.Synopsis
    This function checks if MFA during device registration is being enforced in Entra ID settings and in conditional access policies.

.Description
    When MFA is required during device registration in Conditional Access policies, it must be disabled in the Entra ID Device settings.
    When both are enabled, the conditional access policy with the "Register device" user action will not work as expected. More information
    can be foun at: https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-all-users-device-registration#create-a-conditional-access-policy

.Example
    Test-MtRegistrationMfaConflict

.LINK
    https://maester.dev/docs/commands/Test-MtRegistrationMfa
#>

function Test-MtRegistrationMfaConflict {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    # Testing conneciton with graph
    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    # Initialize the test result variables
    $testResultMarkdown = ""
    $misconfigPolicies = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Get the enabled conditional access policies
    $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
    Write-Verbose "Retrieved conditional access policies:`n $policies"

    # Get device registration settings in Entra ID
    $deviceRegSettings = Invoke-MtGraphRequest -RelativeUri "policies/deviceRegistrationPolicy" -apiVersion "beta" -ErrorAction Stop
    Write-Verbose "Retrieved device registration settings:`n $deviceRegSettings"

    # Check if MFA with Device Registration is required in Entra settings
    if ($deviceRegSettings.multiFactorAuthConfiguration -ne "notRequired") {
        foreach ($policy in $policies) {
            # If there is a conditional access policy requiring controls on register device as well, we found a misconfig
            if ($policy.conditions.applications.includeUserActions -contains "urn:user:registerdevice") {
                # Save the policy details to the list
                Write-Verbose "Found a conditional access policy requiring controls on register device: $($policy.displayName)"
                $misconfigPolicy = [PSCustomObject]@{
                    Id          = $policy.id
                    DisplayName = $policy.displayName
                }
                $misconfigPolicies.Add($misconfigPolicy) | Out-Null
            }
        }
    }

    if ($misconfigPolicies.Count -gt 0) {
        $testResultMarkdown = "Misconfigurations detected in conditional access policies requiring controls on register device:`n`n%TestResult%"
        $result = "| Policy Display Name | Policy Id |`n"
        $result += "| --- | --- |`n"
        foreach ($policy in $misconfigPolicies) {
            $policyMdLink = "[$($policy.DisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccessPolicyBlade/~/policies/$($policy.Id))"
            $result += "| $($policyMdLink) | $($policy.Id) |`n"
            Write-Verbose "Adding policy $($policy.DisplayName) with id $($policy.Id) to markdown table."
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        $return = $false
    } else {
        $testResultMarkdown = "MFA for device registration is not required in Entra ID settings, meaning no conflicts can exist with conditional access policies."
        $return = $true
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $return
}