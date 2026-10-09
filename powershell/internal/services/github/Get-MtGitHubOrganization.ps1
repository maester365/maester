function Get-MtGitHubOrganization {
    <#
    .SYNOPSIS
    Internal: Gets the connected GitHub organization object using the session cache.
    #>
    [CmdletBinding()]
    param()

    if ($null -eq $__MtSession.GitHubConnection -or
        $__MtSession.GitHubConnection.Connected -ne $true) {
        throw "Not connected to GitHub. Call Connect-MtGitHub first."
    }

    # Connect-MtGitHub stores the raw organization login; encode it here for the path segment.
    $encodedOrg = [System.Uri]::EscapeDataString($__MtSession.GitHubConnection.Organization)
    Invoke-MtGitHubRequest -RelativeUri "/orgs/$encodedOrg"
}
