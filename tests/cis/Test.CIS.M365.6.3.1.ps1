function Test-MtCisUsersCannotInstallOutlookAddIns {
    <#
    .SYNOPSIS
        Checks that the default role assignment policy does not let users install add-ins.

    .DESCRIPTION
        Checks that the default role assignment policy does not include the roles that let users install their own apps: My Custom Apps, My Marketplace Apps and My ReadWriteMailbox Apps.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.3.1, L2)

    .EXAMPLE
        Test-MtCisUsersCannotInstallOutlookAddIns

        Returns true if users cannot install Outlook add-ins with the default role assignment policy.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.3.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.3.1',
        Title = 'Ensure users installing Outlook add-ins is not allowed',
        Product = 'exchange',
        Feature = 'outlook',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1137.006',
        Control = ('cis-m365:6.3.1', 'nist-800-53-r5:CM-7'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the default role assignment policy...'
    $deniedRoles = @('My Custom Apps', 'My Marketplace Apps', 'My ReadWriteMailbox Apps')
    $policy = @(Get-MtExo -Request RoleAssignmentPolicy) | Where-Object { $_.IsDefault -eq $true } | Select-Object -First 1
    $assigned = @($policy.AssignedRoles | Where-Object { $deniedRoles -contains $_ })
    $testResult = $null -ne $policy -and $assigned.Count -eq 0

    $passText = 'The default role assignment policy does not let users install Outlook add-ins.'
    $failText = if ($null -eq $policy) { 'No default role assignment policy was found.' } else { 'The default role assignment policy lets users install Outlook add-ins.' }

    $resultMd = "| Role | Assigned to default policy | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($role in $deniedRoles) {
        $isAssigned = @($policy.AssignedRoles) -contains $role
        $resultMd += "| $role | $isAssigned | $(if ($isAssigned) { '❌ Fail' } else { '✅ Pass' }) |`n"
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
