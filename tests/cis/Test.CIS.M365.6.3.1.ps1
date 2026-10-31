function Test-MtCisUserCannotInstallOutlookAddIn {
    <#
    .SYNOPSIS
        Checks that the default role assignment policy does not let users install Outlook add-ins.

    .DESCRIPTION
        Checks that the default role assignment policy does not include the roles that let users install their own apps: My Custom Apps, My Marketplace Apps and My ReadWriteMailbox Apps. Custom role assignment policies are not evaluated, as in the CIS audit procedure.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.3.1, L2)

    .EXAMPLE
        Test-MtCisUserCannotInstallOutlookAddIn

        Returns true if the default role assignment policy assigns none of the add-in installation roles.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.3.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.3.1',
        Title = 'Ensure users installing Outlook add-ins is not allowed',
        Product = 'exchange',
        Feature = 'outlook',
        Area = 'applications',
        ResourceType = 'Policy',
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
    if ($null -eq $defaultPolicy) {
        Add-MtTestResultDetail -Result 'The default role assignment policy was not returned; the CIS add-in roles could not be checked.'
        return $false
    }
    $report = foreach ($role in $deniedRoles) {
        [pscustomobject]@{ Policy = $defaultPolicy.Name; Role = $role; Assigned = @($defaultPolicy.AssignedRoles) -contains $role }
    }
    $testResult = @($report | Where-Object { $_.Assigned }).Count -eq 0

    $passText = 'The default role assignment policy does not let users install Outlook add-ins.'
    $failText = 'The default role assignment policy lets users install Outlook add-ins.'

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
