function Test-MtDisaInactiveAccount {
    <#
    .SYNOPSIS
    Checks that no enabled user account has been inactive for 35 days or more.

    .DESCRIPTION
    The DISA Microsoft Entra ID STIG (V-270204) asks that accounts are disabled automatically after 35 days of
    inactivity. Its check lists the enabled users whose last interactive sign-in (signInActivity.lastSignInDateTime)
    is older than 35 days, or who never signed in and were created more than 35 days ago, and is a finding when any
    such account is still enabled.

    This check does the same: it reads every enabled user, members and guests, and fails when one of them is
    inactive for the given number of days (35 by default). Microsoft Entra ID has no setting that disables
    accounts by itself, so the fix is a process (an access review of inactive users, or an automation) that
    disables them.

    ASD.ISM-1648 reads the same sign-in data for privileged users only, so this is a test of its own.

    .EXAMPLE
    Test-MtDisaInactiveAccount

    Returns true when every enabled user signed in within the last 35 days.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270204
    #>
    [MaesterTest(
        Id = 'DISA.V-270204',
        Title = 'Microsoft Entra ID must automatically disable accounts after a 35-day period of account inactivity.',
        Product = 'entra',
        Feature = 'identity-governance',
        Area = 'identity-lifecycle',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = 'disa-stig-entra-id:V-270204',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Lifecycle = 'Preview',
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Days without a sign-in after which an account must be disabled.
        [ValidateRange(1, 365)]
        [int] $MaximumInactiveDays = 35
    )

    $cutoff = [datetime]::UtcNow.AddDays(-$MaximumInactiveDays)
    $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -Filter 'accountEnabled eq true' -Select id, userPrincipalName, displayName, userType, accountEnabled, createdDateTime, signInActivity)
    $inactive = foreach ($user in $users) {
        if ($user.accountEnabled -ne $true) { continue }
        # The STIG's audit reads the interactive sign-in only.
        $lastSignIn = Get-MtUserLastSignIn -User $user -InteractiveOnly
        $isInactive = if ($lastSignIn) { $lastSignIn -lt $cutoff } else { $user.createdDateTime -and ([datetime]$user.createdDateTime).ToUniversalTime() -lt $cutoff }
        if ($isInactive) {
            [pscustomobject]@{
                userPrincipalName = $user.userPrincipalName
                UserType          = $user.userType
                LastSignIn        = if ($lastSignIn) { $lastSignIn.ToString('yyyy-MM-dd') } else { 'Never' }
            }
        }
    }
    $inactive = @($inactive)
    $testResult = $inactive.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Every enabled user signed in within the last $MaximumInactiveDays days ($($users.Count) users checked)."
    } else {
        $shown = @($inactive | Sort-Object LastSignIn, userPrincipalName | Select-Object -First 100)
        $table = "| User | Type | Last interactive sign-in |`n| --- | --- | --- |`n"
        foreach ($user in $shown) { $table += "| $(Get-MtSafeMarkdown $user.userPrincipalName) | $($user.UserType) | $($user.LastSignIn) |`n" }
        if ($inactive.Count -gt $shown.Count) { $table += "`nThe first $($shown.Count) of $($inactive.Count) accounts are shown.`n" }
        $testResultMarkdown = "$($inactive.Count) enabled account(s) have not signed in for $MaximumInactiveDays days or more. Disable them, or document why they must stay enabled.`n`n$table"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
