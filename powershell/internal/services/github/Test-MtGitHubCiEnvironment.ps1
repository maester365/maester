function Test-MtGitHubCiEnvironment {
    <#
    .SYNOPSIS
    True when a CI system sets its environment variable: GITHUB_ACTIONS, TF_BUILD (Azure DevOps) or CI.

    .DESCRIPTION
    GITHUB_ACTIONS and TF_BUILD are compared with the values those systems set. CI counts when it is set
    to anything but 0 or false, so a developer who exports CI=false is not treated as a pipeline.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $env:GITHUB_ACTIONS -eq 'true' -or
    $env:TF_BUILD -eq 'True' -or
    (-not [string]::IsNullOrEmpty($env:CI) -and $env:CI -notin '0', 'false')
}
