function Test-MtAsdInactivePrivilegedAccess {
    <#
    .SYNOPSIS
    Checks that no enabled account with a privileged directory role has been inactive for 45 days or more.

    .DESCRIPTION
    ISM-1648 (Essential Eight, Restrict administrative privileges, Maturity Level Two) asks that privileged
    access to systems and their resources is disabled after 45 days of inactivity.

    The check lists the users with an active or eligible assignment to a directory role that Microsoft Entra
    marks as privileged, and reads the last sign-in of each. A user fails when the account is enabled and the
    most recent interactive or non-interactive sign-in is older than the number of days given (45 by
    default), or when the account has never signed in and was created before that. The emergency access
    accounts named in the Maester configuration (EmergencyAccessAccounts) are left out, because they are
    meant to stay unused.

    .EXAMPLE
    Test-MtAsdInactivePrivilegedAccess

    Returns true when every enabled privileged user signed in within the last 45 days.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1648
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1648',
        Title = 'Privileged access to systems and their resources is disabled after 45 days of inactivity.',
        Product = 'entra',
        Feature = 'roles',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('essential-eight:ISM-1648', 'nist-800-53-r5:AC-2(3)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Days without a sign-in after which privileged access must be disabled.
        [ValidateRange(1, 365)]
        [int] $InactiveDays = 45
    )

    $rolesOf = Get-MtAsdPrivilegedUser
    if ($rolesOf.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $cutoff = [datetime]::UtcNow.AddDays(-$InactiveDays)
    $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId @($rolesOf.Keys) -Select id, userPrincipalName, displayName, accountEnabled, createdDateTime, signInActivity)
    $inactive = foreach ($user in $users) {
        if ($user.accountEnabled -ne $true) { continue }
        $signIns = @($user.signInActivity.lastSignInDateTime, $user.signInActivity.lastNonInteractiveSignInDateTime | Where-Object { $_ } | ForEach-Object { [datetime]$_ })
        $lastSignIn = if ($signIns.Count -gt 0) { ($signIns | Measure-Object -Maximum).Maximum.ToUniversalTime() } else { $null }
        $isInactive = if ($lastSignIn) { $lastSignIn -lt $cutoff } else { $user.createdDateTime -and ([datetime]$user.createdDateTime).ToUniversalTime() -lt $cutoff }
        if ($isInactive) {
            [pscustomobject]@{
                id                = $user.id
                displayName       = $user.displayName
                userPrincipalName = $user.userPrincipalName
                LastSignIn        = if ($lastSignIn) { $lastSignIn.ToString('yyyy-MM-dd') } else { 'Never' }
                Roles             = $rolesOf[$user.id] -join ', '
            }
        }
    }
    $inactive = @($inactive)
    $testResult = $inactive.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Every enabled user with a privileged directory role signed in within the last $InactiveDays days ($($rolesOf.Count) users checked)."
    } else {
        $table = "| User | Last sign-in | Privileged roles |`n| --- | --- | --- |`n"
        foreach ($user in ($inactive | Sort-Object userPrincipalName)) { $table += "| $($user.userPrincipalName) | $($user.LastSignIn) | $($user.Roles) |`n" }
        $testResultMarkdown = "$($inactive.Count) enabled user(s) with a privileged directory role have not signed in for $InactiveDays days or more. Disable the account or remove the role, and let an access review or a PIM alert catch the next one.`n`n$table"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
