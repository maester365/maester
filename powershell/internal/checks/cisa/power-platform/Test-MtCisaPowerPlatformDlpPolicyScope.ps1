function Test-MtCisaPowerPlatformDlpPolicyScope {
    <#
    .SYNOPSIS
    Evaluates whether Power Platform data loss prevention (DLP) policies cover the environments a CISA SCuBA check names.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.2.1 and MS.POWERPLATFORM.2.2.
    A policy covers an environment when its scope is all environments, when it names the environment in an
    OnlyEnvironments scope, or when it excludes other environments but not this one.
    DefaultEnvironment passes when at least one policy covers the default environment.
    NonDefaultEnvironment passes when a policy applies to all environments, or every non-default environment is covered.

    .EXAMPLE
    Test-MtCisaPowerPlatformDlpPolicyScope -Scope DefaultEnvironment

    Returns true when a DLP policy applies to the default environment.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # DefaultEnvironment checks the default environment; NonDefaultEnvironment checks every other environment.
        [Parameter(Mandatory)]
        [ValidateSet('DefaultEnvironment', 'NonDefaultEnvironment')]
        [string] $Scope
    )

    $environments = @(Get-MtPowerPlatformEnvironment)
    $policies = @(Get-MtPowerPlatformDlpPolicy)
    $defaultEnvironments = @($environments | Where-Object { $_.IsDefault })
    if ($defaultEnvironments.Count -ne 1) {
        throw "Expected exactly one default Power Platform environment; received $($defaultEnvironments.Count)."
    }

    $covers = {
        param($Policy, $EnvironmentName)
        switch ($Policy.Scope) {
            'AllEnvironments' { $true }
            'OnlyEnvironments' { $Policy.Environments -contains $EnvironmentName }
            default { $Policy.Environments -notcontains $EnvironmentName }
        }
    }

    $defaultName = $defaultEnvironments[0].Name
    if ($Scope -eq 'DefaultEnvironment') {
        $coveringPolicies = @($policies | Where-Object { & $covers $_ $defaultName })
        $testResult = $coveringPolicies.Count -gt 0

        if ($testResult) {
            $message = 'Well done. At least one DLP policy applies to the default Power Platform environment.'
        }
        elseif ($policies.Count -eq 0) {
            $message = 'No Power Platform DLP policy exists. Create a policy that restricts connectors in the default environment.'
        }
        else {
            $message = 'No Power Platform DLP policy applies to the default environment. Add the default environment to a DLP policy scope.'
        }

        $resultMd = "| Policy | Scope | Covers default environment |`n"
        $resultMd += "| --- | --- | --- |`n"
        foreach ($policy in $policies) {
            $covered = if (& $covers $policy $defaultName) { 'Yes' } else { 'No' }
            $resultMd += "| $(Get-MtSafeMarkdown $policy.DisplayName) | $(Get-MtSafeMarkdown $policy.Scope) | $covered |`n"
        }
    }
    else {
        $nonDefaultEnvironments = @($environments | Where-Object { -not $_.IsDefault })
        $allEnvironmentPolicies = @($policies | Where-Object { $_.Scope -eq 'AllEnvironments' })
        $uncovered = @($nonDefaultEnvironments | Where-Object {
                $environment = $_
                -not ($policies | Where-Object { & $covers $_ $environment.Name })
            })
        $testResult = $allEnvironmentPolicies.Count -gt 0 -or $uncovered.Count -eq 0

        if ($allEnvironmentPolicies.Count -gt 0) {
            $message = 'Well done. At least one DLP policy applies to all Power Platform environments.'
        }
        elseif ($nonDefaultEnvironments.Count -eq 0) {
            $message = 'Well done. The tenant has no non-default Power Platform environments that need a DLP policy.'
        }
        elseif ($testResult) {
            $message = 'Well done. Every non-default Power Platform environment is covered by a DLP policy.'
        }
        else {
            $message = 'Some non-default Power Platform environments are not covered by any DLP policy. Add them to a DLP policy scope.'
        }

        $resultMd = "| Environment | Type | Covered by a DLP policy |`n"
        $resultMd += "| --- | --- | --- |`n"
        foreach ($environment in $nonDefaultEnvironments) {
            $covered = if ($environment -in $uncovered) { 'No' } else { 'Yes' }
            $resultMd += "| $(Get-MtSafeMarkdown $environment.DisplayName) | $(Get-MtSafeMarkdown $environment.EnvironmentType) | $covered |`n"
        }
    }

    Add-MtTestResultDetail -Result "$message`n`n$resultMd"
    return $testResult
}
