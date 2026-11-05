function Get-MtMfaRegistrationShare {
    <#
    .SYNOPSIS
    Counts the enabled member users who are registered for multifactor authentication, for the mfa-registered
    measure.

    .DESCRIPTION
    The reader of the mfa-registered measure (powershell/assets/MaesterMeasures.psd1), which decides the step
    entra.mfa-registered of the defender's path. User-risk and sign-in-risk policies ask users to complete MFA, and
    a user who hasn't registered a method can't, so the share of registered users says whether those policies can
    be turned on.

    Reads the authentication methods registration report (reports/authenticationMethods/userRegistrationDetails),
    which needs Microsoft Entra ID P1, through the Graph cache. A member user counts when isMfaRegistered is true.
    Left out of the count:

    - disabled users, which the report also lists;
    - the emergency access accounts in the Maester configuration (EmergencyAccessAccounts), and the users in the
      emergency access groups it names, because they stay excluded from these policies;
    - the users that hold a directory synchronization role, which Conditional Access policies exclude too.

    A configured emergency access account that can't be found stops the reader with an error, as it does in the
    checks that read them, so the figure never counts an account that should have been left out.

    Returns an object with Count (registered users), Total (the users counted) and Objects (the users who aren't
    registered, as Type, Id and DisplayName, administrators first).

    .EXAMPLE
    Get-MtMfaRegistrationShare

    Returns the number of enabled member users who are registered for MFA, apart from the emergency access and
    directory synchronization accounts.
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
    $notRegistered = @($users | Where-Object { $_.isMfaRegistered -ne $true })

    # The object facts user.mfaRegistered (design section 12), under the object ID and the UPN, are written for
    # these users once Add-MtAffectedObjectFact takes a Key.
    [pscustomobject][ordered]@{
        Count   = $users.Count - $notRegistered.Count
        Total   = $users.Count
        Objects = @(
            $notRegistered |
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
