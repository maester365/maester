function Test-MtCheckMT1003 {
    <#
    .SYNOPSIS
    At least one Conditional Access policy is configured with All Apps.

    .DESCRIPTION
    Runs the shared check Test-MtCaAllAppsExists with -SkipCheckAllUsers.
    #>
    [MaesterTest(
        Id = 'MT.1003',
        Title = 'At least one Conditional Access policy is configured with All Apps.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Tag = ('CA', 'Maester'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'merill',
        Contributor = 'f-bader'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtCaAllAppsExists -SkipCheckAllUsers
    if ($null -eq $result) { return $null }
    return $result
}
