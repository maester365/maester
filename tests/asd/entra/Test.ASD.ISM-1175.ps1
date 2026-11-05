function Test-MtAsdPrivilegedUserMailbox {
    <#
    .SYNOPSIS
    Checks for mailbox-providing Exchange Online service plans on users with a privileged directory role.

    .DESCRIPTION
    ISM-1175 (Essential Eight, Restrict administrative privileges, Maturity Level One) asks that privileged
    user accounts, excluding those explicitly authorised to access online services, are prevented from
    accessing the internet, email and web services. ASD's assessment guide tests the email part by listing the
    privileged accounts that have an email address. ISM-0445 asks that privileged human users have a dedicated
    account for privileged duties, and a mailbox on an administrator account is the usual sign that the account
    is also used for everyday work.

    The check lists the users with an active or eligible assignment to a directory role that Microsoft Entra
    marks as privileged, directly or through a role-assignable group, and fails for each one that has an
    enabled Exchange Online service plan that provides a mailbox (Plan 1, Plan 2, Kiosk or Essentials). The
    Exchange Foundation plan that comes with Entra ID, Intune and Defender licences creates no mailbox and is
    not counted. The emergency access accounts named in the Maester configuration
    (EmergencyAccessAccounts) are left out. The absence of these plans does not prove an account has no mailbox
    or is used only for privileged duties. Internet and web-service access are not checked.

    MT.1028 looks for mailboxes on permanent Control Plane assignments only. ASD's test covers every privileged
    account, eligible ones included, so this check reads them itself.

    .EXAMPLE
    Test-MtAsdPrivilegedUserMailbox

    Returns true when no privileged user has an enabled mailbox-providing Exchange Online plan.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1175
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1175',
        Title = 'Privileged user accounts (excluding those explicitly authorised to access online services) are prevented from accessing the internet, email and web services.',
        Product = 'entra',
        Feature = 'roles',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1566'),
        Control = ('essential-eight:ISM-1175', 'essential-eight:ISM-0445', 'nist-800-53-r5:AC-6(2)', 'nist-800-53-r5:AC-6(5)'),
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

    $rolesOf = Get-MtPrivilegedRoleUser -ExcludeEmergencyAccessAccount
    if ($rolesOf.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable
        return $false
    }

    $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId @($rolesOf.Keys) -Select id, userPrincipalName, displayName, assignedPlans)
    $withMailbox = @($users | Where-Object {
            @($_.assignedPlans | Where-Object { $_.servicePlanId -in $MailboxServicePlanId -and $_.capabilityStatus -eq 'Enabled' }).Count -gt 0
        } | ForEach-Object {
            [pscustomobject]@{ id = $_.id; displayName = $_.displayName; userPrincipalName = $_.userPrincipalName; Roles = $rolesOf[$_.id] -join ', ' }
        })
    $testResult = $withMailbox.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "None of the $($rolesOf.Count) users with a privileged directory role has an enabled mailbox-providing Exchange Online service plan."
    } else {
        $table = "| User | Privileged roles |`n| --- | --- |`n"
        foreach ($user in ($withMailbox | Sort-Object userPrincipalName)) { $table += "| $($user.userPrincipalName) | $($user.Roles) |`n" }
        $testResultMarkdown = "$($withMailbox.Count) of $($rolesOf.Count) users with a privileged directory role have an enabled mailbox-providing Exchange Online service plan. Give each administrator a separate, unlicensed account for privileged duties and move the role to it.`n`n$table"
    }
    $testResultMarkdown += "`n`nThis check does not verify mailbox existence, access to other email or web services, or whether the account is used only for privileged duties."
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
