function Test-MtAsdDedicatedPrivilegedAccount {
    <#
    .SYNOPSIS
    Checks that users with a privileged directory role have no Exchange Online mailbox, so that the account is dedicated to privileged duties.

    .DESCRIPTION
    ISM-0445 (Essential Eight, Restrict administrative privileges, Maturity Level One) asks that privileged
    users are assigned a dedicated privileged user account to be used solely for duties requiring privileged
    access, and ISM-1175 that privileged user accounts are prevented from accessing the internet, email and
    web services.

    A mailbox on an administrator account is the usual sign that the account is also used for everyday work,
    and it exposes the privileged account to phishing. The check lists the users with an active or eligible
    assignment to a directory role that Microsoft Entra marks as privileged, and fails for each one that has an
    enabled Exchange Online service plan that provides a mailbox (Plan 1, Plan 2, Kiosk or Essentials). The
    Exchange Foundation plan that comes with Entra ID, Intune and Defender licences creates no mailbox and is
    not counted. The emergency access accounts named in the Maester configuration
    (EmergencyAccessAccounts) are left out.

    .EXAMPLE
    Test-MtAsdDedicatedPrivilegedAccount

    Returns true when no privileged user has an Exchange Online mailbox.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-0445
    #>
    [MaesterTest(
        Id = 'ASD.ISM-0445',
        Title = 'Privileged users are assigned a dedicated privileged user account.',
        Product = 'entra',
        Feature = 'roles',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1566'),
        Control = ('essential-eight:ISM-0445', 'essential-eight:ISM-1175', 'nist-800-53-r5:AC-6(2)', 'nist-800-53-r5:AC-6(5)'),
        Service = 'Graph',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The IDs of the Exchange Online service plans that provide a mailbox: Plan 2, Plan 1, Kiosk and Essentials.
        [string[]] $MailboxServicePlanId = @(
            'efb87545-963c-4e0d-99df-69c6916d9eb0',
            '9aaf7827-d63c-4b61-89c3-182f06f82e5c',
            '4a82b400-a79f-41a4-b4e2-e94f5787b113',
            '1126bef5-da20-4f07-b45e-ad25d2581aa8'
        )
    )

    $rolesOf = Get-MtAsdPrivilegedUser
    if ($rolesOf.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $null
    }

    $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId @($rolesOf.Keys) -Select id, userPrincipalName, displayName, assignedPlans)
    $withMailbox = @($users | Where-Object {
            @($_.assignedPlans | Where-Object { $_.servicePlanId -in $MailboxServicePlanId -and $_.capabilityStatus -eq 'Enabled' }).Count -gt 0
        } | ForEach-Object {
            [pscustomobject]@{ id = $_.id; displayName = $_.displayName; userPrincipalName = $_.userPrincipalName; Roles = $rolesOf[$_.id] -join ', ' }
        })
    $testResult = $withMailbox.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. None of the $($rolesOf.Count) users with a privileged directory role has an Exchange Online mailbox."
    } else {
        $table = "| User | Privileged roles |`n| --- | --- |`n"
        foreach ($user in ($withMailbox | Sort-Object userPrincipalName)) { $table += "| $($user.userPrincipalName) | $($user.Roles) |`n" }
        $testResultMarkdown = "$($withMailbox.Count) of $($rolesOf.Count) users with a privileged directory role have an Exchange Online mailbox. Give each administrator a separate, unlicensed account for privileged duties and move the role to it.`n`n$table"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
