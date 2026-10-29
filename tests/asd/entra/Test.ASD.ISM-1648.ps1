function Test-MtAsdInactivePrivilegedAccess {
    <#
    .SYNOPSIS
    Checks that no enabled account with a privileged directory role has been inactive for 45 days or more.

    .DESCRIPTION
    ISM-1648 (Essential Eight, Restrict administrative privileges, Maturity Level Two) asks that privileged
    access to systems and their resources is disabled after 45 days of inactivity.

    The check lists the users with an active or eligible assignment to a directory role that Microsoft Entra
    marks as privileged, directly or through a role-assignable group, and reads the last sign-in of each. A
    user fails when the account is enabled and the most recent successful interactive or non-interactive
    sign-in is older than the number of days given (45 by default), or when no successful sign-in is recorded
    and the account was created before that. Microsoft Graph has recorded successful sign-ins since December
    2023 without backfilling older activity. The emergency access accounts named in the Maester configuration
    (EmergencyAccessAccounts) are left out, because they are meant to stay unused.

    MT.1029 reports the same accounts through the Privileged Identity Management stale accounts alert, whose
    number of days each tenant sets. ASD names 45 days, so this check reads the sign-ins itself.

    .EXAMPLE
    Test-MtAsdInactivePrivilegedAccess

    Returns true when no enabled privileged user is known to have been inactive for 45 days or more.
    Reports Investigate when a user's inactivity cannot be determined.

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
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
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

    $rolesOf = Get-MtPrivilegedRoleUser -ExcludeEmergencyAccessAccount
    if ($rolesOf.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $false
    }

    $cutoff = [datetime]::UtcNow.AddDays(-$InactiveDays)
    $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId @($rolesOf.Keys) -Select id, userPrincipalName, displayName, accountEnabled, createdDateTime, signInActivity)
    $unknown = [System.Collections.Generic.List[object]]::new()
    $inactive = foreach ($user in $users) {
        if ($user.accountEnabled -ne $true) { continue }
        $lastSignIn = if ($user.signInActivity.lastSuccessfulSignInDateTime) { ([datetime]$user.signInActivity.lastSuccessfulSignInDateTime).ToUniversalTime() } else { $null }
        if (-not $lastSignIn -and -not $user.createdDateTime) {
            $unknown.Add([pscustomobject]@{ User = $user.userPrincipalName; Roles = $rolesOf[$user.id] -join ', ' })
            continue
        }
        $isInactive = if ($lastSignIn) { $lastSignIn -lt $cutoff } else { ([datetime]$user.createdDateTime).ToUniversalTime() -lt $cutoff }
        if ($isInactive) {
            [pscustomobject]@{
                id                = $user.id
                displayName       = $user.displayName
                userPrincipalName = $user.userPrincipalName
                LastSignIn        = if ($lastSignIn) { $lastSignIn.ToString('yyyy-MM-dd') } else { 'Not recorded' }
                Roles             = $rolesOf[$user.id] -join ', '
            }
        }
    }
    $inactive = @($inactive)
    $testResult = $inactive.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "No enabled user with a privileged directory role is known to have been inactive for $InactiveDays days or more ($($rolesOf.Count) users checked)."
    } else {
        $table = "| User | Last successful sign-in | Privileged roles |`n| --- | --- | --- |`n"
        foreach ($user in ($inactive | Sort-Object userPrincipalName)) { $table += "| $($user.userPrincipalName) | $($user.LastSignIn) | $($user.Roles) |`n" }
        $testResultMarkdown = "$($inactive.Count) enabled user(s) with a privileged directory role have no successful sign-in recorded within $InactiveDays days. Disable the account or remove the role, and let an access review or a PIM alert catch the next one.`n`n$table"
    }
    if ($unknown.Count -gt 0) {
        $testResultMarkdown += "`n`nThe inactivity of $($unknown.Count) user(s) cannot be determined because neither a successful sign-in nor an account creation date was returned:`n`n| User | Privileged roles |`n| --- | --- |`n"
        foreach ($user in ($unknown | Sort-Object User)) { $testResultMarkdown += "| $($user.User) | $($user.Roles) |`n" }
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:($testResult -and $unknown.Count -gt 0)
    return $testResult
}
