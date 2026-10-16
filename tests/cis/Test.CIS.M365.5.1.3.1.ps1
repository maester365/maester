function Test-MtCisUsersCannotCreateSecurityGroups {
    <#
    .SYNOPSIS
        Checks that non-admin users cannot create security groups.

    .DESCRIPTION
        Checks the default user role permissions in the authorization policy and passes when users are not allowed to create security groups in the Microsoft Entra admin centers, with PowerShell or through the API.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.3.1, L1)

    .EXAMPLE
        Test-MtCisUsersCannotCreateSecurityGroups

        Returns true if default users cannot create security groups.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.3.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.3.1',
        Title = 'Ensure users cannot create security groups',
        Product = 'entra',
        Feature = 'groups',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:5.1.3.1', 'nist-800-53-r5:AC-6'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the authorization policy...'
    $authorizationPolicy = Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy' -DisableCache
    $value = $authorizationPolicy.defaultUserRolePermissions.allowedToCreateSecurityGroups
    $testResult = $value -eq $false

    $passText = 'Users cannot create security groups.'
    $failText = 'Users can create security groups.'

    $checks = @([pscustomobject]@{ Setting = 'allowedToCreateSecurityGroups'; Value = $(if ($null -eq $value) { 'Not found' } else { $value }); Pass = $testResult })
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
