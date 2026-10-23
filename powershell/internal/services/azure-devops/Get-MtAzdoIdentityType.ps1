function Get-MtAzdoIdentityType {
    <#
    .SYNOPSIS
    Returns how the current ADOPS connection is authenticated: 'User', 'ServicePrincipal' or 'Unknown'.

    .DESCRIPTION
    Decodes the access token ADOPS sends with its API calls (NewAzToken, used by InvokeADOPSRestMethod) and reads
    the idtyp claim. If idtyp is not present, a token carrying an scp claim is treated as delegated (user).

    If the token can't be read (for example if a future ADOPS version renames NewAzToken), it falls back to the
    Identity stored by Connect-ADOPS: an e-mail address means a user, anything else is treated as a service
    principal. Managed identities are reported as 'ServicePrincipal'.

    .EXAMPLE
    Get-MtAzdoIdentityType

    Returns 'User' after an interactive Connect-ADOPS, or 'ServicePrincipal' when connected with a workload or
    managed identity token.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        # Same token ADOPS sends (for -OAuthToken it is the token passed to Connect-ADOPS)
        $jwt = & (Get-Module ADOPS) { (NewAzToken).Token }
        $payload = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
        $payload = $payload.PadRight($payload.Length + (4 - $payload.Length % 4) % 4, '=')
        $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json

        switch ($claims.idtyp) {
            'user' { 'User' }
            'app' { 'ServicePrincipal' }   # also covers managed identities
            default { if ($claims.scp) { 'User' } else { 'ServicePrincipal' } }
        }
    } catch {
        Write-Verbose "Could not decode the ADOPS token, falling back to Get-ADOPSConnection: $_"
        try {
            $identity = (Get-ADOPSConnection).Identity
            if ($identity -match '@') { 'User' } elseif ($identity) { 'ServicePrincipal' } else { 'Unknown' }
        } catch {
            Write-Verbose "Could not read the ADOPS connection: $_"
            'Unknown'
        }
    }
}
