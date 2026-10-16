function Get-MtUserInteractive {
    <#
    .SYNOPSIS
    Returns if the current session is interactive or is being run in a non-interactive environment (e.g. Azure DevOps Pipeline or GitHub Actions).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    return ([Environment]::UserInteractive -and !([Environment]::GetCommandLineArgs() | Where-Object { $_ -like '-NonI*' }))
}
