function Get-MtMfaCapableShare {
    <#
    .SYNOPSIS
    Counts the enabled member users who can complete multifactor authentication, for the mfa-capable measure.

    .DESCRIPTION
    The reader of the mfa-capable measure (powershell/assets/MaesterMeasures.psd1), which decides the step
    entra.mfa-registered of the defender's path. User-risk and sign-in-risk policies ask users to complete MFA, and
    a user who hasn't registered a method that is allowed can't, so the share of users who can says whether those
    policies can be turned on.

    Reads the authentication methods registration report (reports/authenticationMethods/userRegistrationDetails),
    which needs Microsoft Entra ID P1, through the Graph cache. A member user counts when isMfaCapable is true: the
    user has registered a strong method that the authentication methods policy allows. isMfaRegistered is not
    enough, because it is also true for a method the policy no longer allows. Left out of the count:

    - disabled users, which the report also lists;
    - the emergency access accounts in the Maester configuration (EmergencyAccessAccounts), and the users in the
      emergency access groups it names, because they stay excluded from these policies;
    - the users that hold a directory synchronization role, which Conditional Access policies exclude too.

    A configured emergency access account that can't be found stops the reader with an error, as it does in the
    checks that read them, so the figure never counts an account that should have been left out.

    Returns an object with Count (users who can complete MFA), Total (the users counted) and Objects (the users who
    can't, as Type, Id and DisplayName, administrators first).

    .EXAMPLE
    Get-MtMfaCapableShare

    Returns the number of enabled member users who can complete MFA, apart from the emergency access and directory
    synchronization accounts.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    # The whole report, with no $select or $filter, so other readers of the report share its cache entry.
    $registrations = @(Invoke-MtGraphRequest -RelativeUri 'reports/authenticationMethods/userRegistrationDetails' | Where-Object { $null -ne $_ })

    $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($user in @(Invoke-MtGraphRequest -RelativeUri 'users' -Filter 'accountEnabled eq false' -Select 'id' | Where-Object { $null -ne $_ })) {
        $null = $excluded.Add([string]$user.id)
    }
    foreach ($account in @(Get-MtEmergencyAccessAccount)) {
        if ($account.Type -eq 'group') {
            $groupUsers = @(Get-MtGroupMember -GroupId $account.ObjectId -Recursive | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' })
            foreach ($member in $groupUsers) { $null = $excluded.Add([string]$member.id) }
        } elseif ($account.ObjectId) {
            $null = $excluded.Add([string]$account.ObjectId)
        }
    }
    foreach ($member in @(Get-MtRoleMember -Role 'DirectorySynchronizationAccounts', 'OnPremisesDirectorySyncAccount' | Where-Object { $_.'@odata.type' -ne '#microsoft.graph.servicePrincipal' })) {
        if ($member.id) { $null = $excluded.Add([string]$member.id) }
    }

    $users = @($registrations | Where-Object { $_.userType -eq 'member' -and $_.id -and -not $excluded.Contains([string]$_.id) })
    $notCapable = @($users | Where-Object { $_.isMfaCapable -ne $true })

    # Object facts for these users (design section 12), under the object ID and the UPN, wait for the engine to list
    # a measure's objects on the Affected objects page: facts attach only to objects the run lists.
    [pscustomobject][ordered]@{
        Count   = $users.Count - $notCapable.Count
        Total   = $users.Count
        Objects = @(
            $notCapable |
                Sort-Object -Property @{ Expression = { $_.isAdmin -eq $true }; Descending = $true }, userPrincipalName, id |
                ForEach-Object {
                    [pscustomobject][ordered]@{
                        Type        = 'User'
                        Id          = [string]$_.id
                        DisplayName = if ($_.userDisplayName) { [string]$_.userDisplayName } else { [string]$_.userPrincipalName }
                    }
                }
        )
    }
}
