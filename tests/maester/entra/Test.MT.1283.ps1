function Test-MT1283 {
    <#
        .SYNOPSIS
            Lists users whose display name is "Unknown" (typically because they have no
            first/last name set), showing their email address since it is the only way
            to identify them.
    #>
    [MaesterTest(
        Id                 = 'MT.1283',
        Title              = 'Should not have users with an "unknown" display name',
        Product            = 'entra',
        Feature            = 'external-identities',
        Area               = 'identity-lifecycle',
        ResourceType       = 'User',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Service            = 'Graph',
        Permission         = ('Graph:Scope:User.Read.All'),
        Lifecycle          = 'Preview',
        Author             = ('rbrayb'),
        Tag                = ('Users')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $users = @(Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri 'users' `
            -Select 'id,displayName,mail,otherMails,userPrincipalName,userType' `
            -ConsistencyLevel eventual)

    $unknownUsers = @($users | Where-Object { $_.displayName -eq 'Unknown' })

    if ($unknownUsers.Count -eq 0) {
        $testResultMarkdown = "No users with an unknown display name were found."
    } else {
        $rows = $unknownUsers | ForEach-Object {
            $email = @($_.mail, ($_.otherMails | Select-Object -First 1), $_.userPrincipalName) | Where-Object { $_ } | Select-Object -First 1
            "| $email | $($_.userType) | $($_.id) |"
        }
        $testResultMarkdown = "**Users with an unknown display name ($($unknownUsers.Count) of $($users.Count)):**`n`n" +
            "| Email address | User type | Id |`n| --- | --- | --- |`n" + ($rows -join "`n")
    }

    Add-MtTestResultDetail -Description "Users whose display name is 'Unknown' typically have no first/last name set in the directory, making them hard to identify in audit logs, access reviews, and sign-in reports. Their email address is shown here since it is the only reliable way to identify them." -Result $testResultMarkdown

    return $unknownUsers.Count -eq 0
}
