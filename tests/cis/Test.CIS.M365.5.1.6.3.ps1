function Test-MtCisGuestInvitationsLimited {
    <#
    .SYNOPSIS
        Checks that only admins and users in the Guest Inviter role can invite guests.

    .DESCRIPTION
        Checks the guest invite settings in the authorization policy and passes when invitations can be sent only by administrators and users with the Guest Inviter role, or by no one.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.6.3, L2)

    .EXAMPLE
        Test-MtCisGuestInvitationsLimited

        Returns true if guest invitations are limited to administrators and Guest Inviters.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.6.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.6.3',
        Title = 'Ensure guest user invitations are limited',
        Product = 'entra',
        Feature = 'external-identities',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1136.003',
        Control = ('cis-m365:5.1.6.3', 'nist-800-53-r5:AC-2'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the authorization policy...'
    $authorizationPolicy = Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy'
    $value = "$($authorizationPolicy.allowInvitesFrom)"
    $testResult = $value -eq 'adminsAndGuestInviters' -or $value -eq 'none'

    $passText = "Guest invitations are limited ($value)."
    $failText = "Guest invitations are not limited to administrators and Guest Inviters ($value)."

    $checks = @([pscustomobject]@{ Setting = 'allowInvitesFrom'; Value = $(if ($value) { $value } else { 'Not found' }); Pass = $testResult })
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
