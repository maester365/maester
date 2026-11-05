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

    For each user it lists, it adds the object facts user.mfaCapable and user.mfaRegistered (design section 12) with
    Add-MtAffectedObjectFact, from the source 'Maester measures', under the object ID and the user principal name,
    so a record has them whichever way it was keyed. A run that doesn't collect affected objects keeps no facts.

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

    # Object facts for the users listed (design section 12), under the object ID and the UPN.
    $facts = foreach ($user in $notCapable) {
        $list = [System.Collections.Generic.List[object]]::new()
        $list.Add(@{ Name = 'Can complete MFA'; Value = 'No: no method the policy allows is registered'; Tone = $(if ($user.isAdmin -eq $true) { 'Risk' } else { 'Warning' }); Key = 'user.mfaCapable'; Raw = $false })
        if ($null -ne $user.isMfaRegistered) {
            $registered = $user.isMfaRegistered -eq $true
            $list.Add(@{ Name = 'MFA'; Value = $(if ($registered) { 'Registered' } else { 'Not registered' }); Tone = $(if ($registered) { 'Info' } else { 'Warning' }); Key = 'user.mfaRegistered'; Raw = $registered })
        }
        $fact = $list.ToArray()
        [pscustomobject]@{ Type = 'User'; Id = [string]$user.id; Fact = $fact }
        if ($user.userPrincipalName) { [pscustomobject]@{ Type = 'User'; Id = [string]$user.userPrincipalName; Fact = $fact } }
    }
    if (@($facts).Count -gt 0) { $facts | Add-MtAffectedObjectFact -Source 'Maester measures' }

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
