function Test-MtCisAllMembersMfaCapable {
    <#
    .SYNOPSIS
        Checks that every member user is registered for a method that can satisfy multifactor authentication.

    .DESCRIPTION
        Lists member users that are not MFA capable in the authentication methods registration report. The Microsoft Entra Connect synchronization account is ignored. A user without a usable second factor depends on the password alone.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.4, L1)

    .EXAMPLE
        Test-MtCisAllMembersMfaCapable

        Returns true if all member users are MFA capable.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.4
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.4',
        Title = 'Ensure all member users are ''MFA capable''',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110.003'),
        Control = ('cis-m365:5.2.3.4', 'nist-800-53-r5:IA-2'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the user registration details report...'
    $filter = "isMfaCapable eq false and userType eq 'Member'"
    $registrations = Invoke-MtGraphRequest -RelativeUri 'reports/authenticationMethods/userRegistrationDetails' -Filter $filter
    $notCapable = @($registrations | Where-Object { $_.userDisplayName -notmatch 'On-Premises Directory Synchronization Service Account' })
    $testResult = $notCapable.Count -eq 0

    $passText = 'All member users are registered for a method that can satisfy multifactor authentication.'
    $failText = "$($notCapable.Count) member user(s) are not MFA capable."

    $resultMd = "| User | Administrator | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($user in ($notCapable | Sort-Object -Property isAdmin, userPrincipalName -Descending | Select-Object -First 50)) {
        $resultMd += "| $($user.userPrincipalName) | $($user.isAdmin) | ❌ Fail |`n"
    }
    if ($notCapable.Count -gt 50) {
        $resultMd += "`nShowing 50 of $($notCapable.Count) users."
    }
    if ($testResult) {
        $resultMd = "| Member users that are not MFA capable | Result |`n| --- | --- |`n| 0 | ✅ Pass |`n"
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
