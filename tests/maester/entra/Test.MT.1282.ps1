function Test-MT1282 {
    <#
        .SYNOPSIS
            Lists guest users whose invitation has not yet been redeemed
            (externalUserState 'PendingAcceptance') for longer than a configurable
            threshold.
    #>
    [MaesterTest(
        Id                 = 'MT.1282',
        Title              = 'Should not have guest invitations pending acceptance beyond the configured threshold',
        Product            = 'entra',
        Feature            = 'external-identities',
        Area               = 'external-access',
        ResourceType       = 'User',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Service            = 'Graph',
        Permission         = ('Graph:Scope:User.Read.All'),
        Lifecycle          = 'Preview',
        Author             = ('rbrayb'),
        Tag                = ('Guests')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Pending invitations older than this many days are flagged.
        [ValidateRange(1, 3650)]
        [int] $MaximumPendingDays = 30
    )

    $guests = @(Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri 'users' `
            -Filter "userType eq 'Guest'" `
            -Select 'id,displayName,userPrincipalName,mail,createdDateTime,externalUserState,externalUserStateChangeDateTime' `
            -ConsistencyLevel eventual)

    $cutoff = (Get-Date).AddDays(-$MaximumPendingDays)

    $stalePendingGuests = @($guests | Where-Object {
            $_.externalUserState -eq 'PendingAcceptance' -and $_.createdDateTime -and ([datetime]$_.createdDateTime) -lt $cutoff
        })

    if ($guests.Count -eq 0) {
        $testResultMarkdown = "No guest users found in this tenant."
    } elseif ($stalePendingGuests.Count -eq 0) {
        $testResultMarkdown = "No guest invitations have been pending acceptance for more than $MaximumPendingDays day(s)."
    } else {
        $rows = $stalePendingGuests | Sort-Object { $_.createdDateTime } | ForEach-Object {
            $email = @($_.mail, $_.userPrincipalName) | Where-Object { $_ } | Select-Object -First 1
            $invitedOn = ([datetime]$_.createdDateTime).ToString('yyyy-MM-dd')
            $daysPending = [math]::Floor(((Get-Date) - [datetime]$_.createdDateTime).TotalDays)
            "| $($_.displayName) | $email | $invitedOn | $daysPending |"
        }
        $testResultMarkdown = "**Guest invitations pending acceptance for more than $MaximumPendingDays day(s) ($($stalePendingGuests.Count) of $($guests.Count)):**`n`n" +
            "| Display name | Email | Invited on | Days pending |`n| --- | --- | --- | --- |`n" + ($rows -join "`n")
    }

    Add-MtTestResultDetail -Description "Guest invitations that remain in 'PendingAcceptance' state for a long time were never redeemed by the invited user. These stale, unredeemed invitations should be reviewed and either re-sent or removed if no longer needed." -Result $testResultMarkdown

    return $stalePendingGuests.Count -eq 0
}
