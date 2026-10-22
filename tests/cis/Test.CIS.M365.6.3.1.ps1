function Test-MtCisUserCannotInstallOutlookAddIn {
    <#
    .SYNOPSIS
        Checks that the role assignment policies that users receive do not let them install add-ins.

    .DESCRIPTION
        Checks that neither the default role assignment policy nor a custom policy that a mailbox uses includes the roles that let users install their own apps: My Custom Apps, My Marketplace Apps and My ReadWriteMailbox Apps.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.3.1, L2)

    .EXAMPLE
        Test-MtCisUserCannotInstallOutlookAddIn

        Returns true if users cannot install Outlook add-ins with the role assignment policies they receive.

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
        Mitre = ('T1137.006', 'T1114.002'),
        Control = ('cis-m365:6.3.1', 'nist-800-53-r5:CM-7'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the role assignment policies...'
    $deniedRoles = @('My Custom Apps', 'My Marketplace Apps', 'My ReadWriteMailbox Apps')
    $policies = @(Get-MtExo -Request RoleAssignmentPolicy)
    $defaultPolicy = $policies | Where-Object { $_.IsDefault -eq $true } | Select-Object -First 1
    $customGranting = @($policies | Where-Object { $_.IsDefault -ne $true -and @($_.AssignedRoles | Where-Object { $deniedRoles -contains $_ }).Count -gt 0 })
    # Mailboxes are read only when a custom policy grants a denied role.
    $inUse = @()
    if ($customGranting.Count -gt 0) {
        $mailboxPolicies = @(Get-MtExo -Request EXOMailboxRoleAssignmentPolicy | ForEach-Object { $_.RoleAssignmentPolicy } | Sort-Object -Unique)
        $inUse = @($customGranting | Where-Object { $mailboxPolicies -contains $_.Name })
    }
    $evaluated = @(@($defaultPolicy) + $inUse | Where-Object { $null -ne $_ })
    $report = foreach ($policy in $evaluated) {
        foreach ($role in $deniedRoles) {
            [pscustomobject]@{ Policy = $policy.Name; Role = $role; Assigned = @($policy.AssignedRoles) -contains $role }
        }
    }
    $testResult = $null -ne $defaultPolicy -and @($report | Where-Object { $_.Assigned }).Count -eq 0

    $passText = 'No role assignment policy that users receive lets them install Outlook add-ins.'
    $failText = if ($null -eq $defaultPolicy) { 'No default role assignment policy was found.' } else { 'A role assignment policy that users receive lets them install Outlook add-ins.' }

    $resultMd = "| Policy | Role | Assigned | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Policy) | $($row.Role) | $($row.Assigned) | $(if ($row.Assigned) { '❌ Fail' } else { '✅ Pass' }) |`n"
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
