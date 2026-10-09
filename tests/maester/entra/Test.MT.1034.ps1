function Get-MtCaWhatIfEmergencyAccessInstance {
    <#
    .SYNOPSIS
    Returns one MT.1034 instance per emergency access account (up to five).

    .DESCRIPTION
    Instance source of the MT.1034 family. The suffix is the account's position in the list (MT.1034.0 to
    MT.1034.4) and the title names the account, as the Maester 2.x rows did.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $emergencyAccessUsers = @(Get-MtUser -Count 5 -UserType 'EmergencyAccess' | Where-Object { $_ })
    for ($i = 0; $i -lt $emergencyAccessUsers.Count; $i++) {
        $user = $emergencyAccessUsers[$i]
        [pscustomobject]@{
            Id    = [string]$i
            Title = "Emergency access users should not be blocked ($($user.userPrincipalName))"
            Data  = $user
        }
    }
}

function Test-MtCaWhatIfEmergencyAccessNotBlocked {
    <#
    .SYNOPSIS
    Checks with the Conditional Access What If API that no Conditional Access policy applies to an emergency access account.

    .DESCRIPTION
    Runs once per emergency access account returned by the instance source and evaluates an Exchange
    ActiveSync sign-in to Office 365 Exchange Online for that account. Passes when no policy applies.

    .LINK
    https://maester.dev/docs/tests/MT.1034
    #>
    [MaesterTest(
        Id = 'MT.1034',
        Title = 'Emergency access users should not be blocked.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Tag = ('CA', 'CAWhatIf', 'Maester'),
        LongRunning,
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        InstanceSource = 'Get-MtCaWhatIfEmergencyAccessInstance',
        Author = 'merill',
        Contributor = ('f-bader', 'milanschwartz', 'jasperbaes')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The emergency access account to evaluate, supplied by the engine.
        $Instance
    )

    $policies = @(Test-MtConditionalAccessWhatIf -UserId $Instance.Data.id -IncludeApplications '00000002-0000-0ff1-ce00-000000000000' -ClientAppType exchangeActiveSync | Where-Object { $_ })
    if ($policies.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. No Conditional Access policy applies to $($Instance.Data.userPrincipalName)."
        return $true
    }
    Add-MtTestResultDetail -Result "These Conditional Access policies apply to $($Instance.Data.userPrincipalName):`n`n%TestResult%" -GraphObjects $policies -GraphObjectType ConditionalAccess
    return $false
}
