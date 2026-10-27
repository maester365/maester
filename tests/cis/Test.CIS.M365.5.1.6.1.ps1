function Test-MtCisCollaborationAllowedDomainsOnly {
    <#
    .SYNOPSIS
        Checks that guest invitations are limited to an allow list of domains.

    .DESCRIPTION
        Checks every B2B management policy and passes when each allows invitations only to specific domains (an allow list) and none uses a deny list, so that guests can be invited only from partner organisations that you approved.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.6.1, L2)

    .EXAMPLE
        Test-MtCisCollaborationAllowedDomainsOnly

        Returns true if collaboration invitations are limited to allowed domains.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.6.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.6.1',
        Title = 'Ensure that collaboration invitations are sent to allowed domains only',
        Product = 'entra',
        Feature = 'external-identities',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1136.003',
        Control = ('cis-m365:5.1.6.1', 'nist-800-53-r5:AC-20'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the B2B management policy...'
    $policies = Invoke-MtGraphRequest -RelativeUri 'legacy/policies' -ApiVersion beta
    $b2bPolicies = @($policies) | Where-Object { $_.type -eq 'B2BManagementPolicy' }
    $checks = @(
        foreach ($b2bPolicy in $b2bPolicies) {
            $policyName = if ($b2bPolicy.displayName) { $b2bPolicy.displayName } else { $b2bPolicy.id }
            $policyType = if ($b2bPolicy.isOrganizationDefault -eq $true) { 'Organization default' } else { 'Non-default' }
            $definitions = @($b2bPolicy.definition)

            if ($definitions.Count -eq 0) {
                [pscustomobject]@{
                    Policy = "$policyName ($policyType)"
                    Value = 'Definition not found'
                    Pass = $false
                }
            } else {
                foreach ($policyDefinition in $definitions) {
                    $definition = $policyDefinition | ConvertFrom-Json
                    $domainPolicy = $definition.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy
                    $names = @($domainPolicy.PSObject.Properties.Name)
                    $hasAllowList = $names -contains 'AllowedDomains'
                    $hasDenyList = $names -contains 'BlockedDomains'
                    $mode = if ($hasAllowList) { 'Allow invitations only to the specified domains' } elseif ($hasDenyList) { 'Deny invitations to the specified domains' } else { 'Allow invitations to any domain' }

                    [pscustomobject]@{
                        Policy = "$policyName ($policyType)"
                        Value = $mode
                        Pass = $hasAllowList -and -not $hasDenyList
                    }
                }
            }
        }
    )
    if ($b2bPolicies.Count -eq 0) {
        $checks = @([pscustomobject]@{ Policy = 'B2B management policy'; Value = 'Not found'; Pass = $false })
    }
    $testResult = $b2bPolicies.Count -gt 0 -and @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'All B2B management policies limit collaboration invitations to an allow list of domains.'
    $failText = if ($b2bPolicies.Count -eq 0) { 'No B2B management policy is configured, so invitations can be sent to any domain.' } else { 'At least one B2B management policy is not limited to an allow list of domains.' }

    $resultMd = "| Policy | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Policy) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
