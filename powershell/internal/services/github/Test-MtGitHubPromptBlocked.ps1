function Test-MtGitHubPromptBlocked {
    <#
    .SYNOPSIS
    True when nobody can answer a GitHub sign-in prompt: input is redirected, the host is not interactive, or a CI system is detected.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    [Console]::IsInputRedirected -or -not [Environment]::UserInteractive -or (Test-MtGitHubCiEnvironment)
}
