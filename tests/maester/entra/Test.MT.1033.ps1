function Get-MtCaWhatIfRegularUserInstance {
    <#
    .SYNOPSIS
    Returns one MT.1033 instance per member user to evaluate (up to five, emergency access accounts excluded).

    .DESCRIPTION
    Instance source of the MT.1033 family. The suffix is the user's position in the list (MT.1033.0 to
    MT.1033.4) and the title names the user, as the Maester 2.x rows did.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $regularUsers = @(Get-MtUser -Count 5 -UserType 'Member' | Where-Object { $_ })
    $emergencyAccessUsers = @(Get-MtUser -Count 5 -UserType 'EmergencyAccess' | Where-Object { $_ })
    $emergencyAccessIds = @($emergencyAccessUsers | ForEach-Object { $_.id })
    $regularUsers = @($regularUsers | Where-Object { $_.id -notin $emergencyAccessIds })

    for ($i = 0; $i -lt $regularUsers.Count; $i++) {
        $user = $regularUsers[$i]
        [pscustomobject]@{
            Id    = [string]$i
            Title = "User should be blocked from using legacy authentication ($($user.userPrincipalName))"
            Data  = $user
        }
    }
}

function Test-MtCaWhatIfLegacyAuthenticationBlocked {
    <#
    .SYNOPSIS
    Checks with the Conditional Access What If API that a user is blocked from using legacy authentication.

    .DESCRIPTION
    Runs once per member user returned by the instance source and evaluates an Exchange ActiveSync
    sign-in to Office 365 Exchange Online for that user.

    .LINK
    https://maester.dev/docs/tests/MT.1033
    #>
    [MaesterTest(
        Id = 'MT.1033',
        Title = 'Users should be blocked from using legacy authentication.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('CA', 'CAWhatIf', 'Maester'),
        LongRunning,
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        InstanceSource = 'Get-MtCaWhatIfRegularUserInstance',
        Author = 'f-bader'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The user to evaluate, supplied by the engine.
        $Instance
    )

    return Test-MtCaWIFBlockLegacyAuthentication -UserId $Instance.Data.id
}
