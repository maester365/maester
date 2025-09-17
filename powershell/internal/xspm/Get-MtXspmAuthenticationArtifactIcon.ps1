<#
.SYNOPSIS
    Get the icon representation for a specific authentication artifact type.
.EXAMPLE
    PS C:\> Get-XspmAuthenticationArtifactIcon -ArtifactType 'PrimaryRefreshToken'
    Returns the icon for the Primary Refresh Token artifact.
.INPUTS
    System.String
#>
function Get-MtXspmAuthenticationArtifactIcon {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ArtifactType
    )
    #region Token Artifact type
    switch ($ArtifactType) {
        'PrimaryRefreshToken'    { "🪙" }
        'UserCookie'             { "🍪" }
        'UserAzureCliSecretData' { "🔑" }
        Default                  { "ℹ️" }
    }
    #endregion
}