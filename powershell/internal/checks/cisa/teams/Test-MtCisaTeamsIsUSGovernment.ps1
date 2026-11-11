function Test-MtCisaTeamsIsUSGovernment {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $context = Get-MgContext -ErrorAction Stop
    if (-not $context) {
        throw 'A Microsoft Graph context is required to determine the Teams environment.'
    }
    return ($context.Environment -in @('USGov', 'USGovDoD') -or
        $__MtSession.TeamsEnvironmentName -in @('TeamsGCCH', 'TeamsDOD'))
}
