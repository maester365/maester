function Test-MtPackNonInteractive {
    <#
    .SYNOPSIS
    True when nobody can answer an install prompt: input is redirected, the host is not interactive, or a CI system is detected.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    [Console]::IsInputRedirected -or -not [Environment]::UserInteractive -or [bool]$env:CI -or [bool]$env:TF_BUILD -or [bool]$env:GITHUB_ACTIONS
}
