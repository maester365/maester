function Test-MtCisCollaborationAllowedDomainsOnly {
    <#
    .SYNOPSIS
        Checks that guest invitations are limited to an allow list of domains.

    .DESCRIPTION
        Checks the organization default B2B collaboration restrictions and passes when invitations are allowed only to specific domains (an allow list) and no deny list is used, so that guests can be invited only from partner organisations that you approved.
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
        ImplementationCost = 'Low',
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
    $b2bPolicy = @($policies) | Where-Object { $_.type -eq 'B2BManagementPolicy' -and $_.isOrganizationDefault -eq $true } | Select-Object -First 1

    $domainPolicy = $null
    if ($b2bPolicy) {
        $definition = @($b2bPolicy.definition)[0] | ConvertFrom-Json
        $domainPolicy = $definition.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy
    }
    $names = @($domainPolicy.PSObject.Properties.Name)
    $hasAllowList = $names -contains 'AllowedDomains'
    $hasDenyList = $names -contains 'BlockedDomains'
    $testResult = $hasAllowList -and -not $hasDenyList

    $passText = 'Collaboration invitations are limited to an allow list of domains.'
    $failText = if ($null -eq $b2bPolicy) { 'No organization-default collaboration restriction policy is configured, so invitations can be sent to any domain.' } else { 'Collaboration invitations are not limited to an allow list of domains.' }

    $mode = if ($hasAllowList) { 'Allow invitations only to the specified domains' } elseif ($hasDenyList) { 'Deny invitations to the specified domains' } else { 'Allow invitations to any domain' }
    $checks = @([pscustomobject]@{ Setting = 'Collaboration restrictions'; Value = $mode; Pass = $testResult })
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
