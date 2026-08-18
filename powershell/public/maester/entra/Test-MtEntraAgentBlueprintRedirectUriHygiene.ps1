function Test-MtEntraAgentBlueprintRedirectUriHygiene {
    <#
    .SYNOPSIS
    Finds Agent Identity Blueprints with wildcard or plain-http redirect URIs.
    .DESCRIPTION
    Checks whether any Agent Identity Blueprint's web redirect URIs contain a wildcard or use
    plain HTTP instead of HTTPS (excluding loopback addresses). A wildcard redirect URI lets a
    token be redirected to any attacker-controlled host that matches the pattern. A plain-http,
    non-loopback redirect URI returns tokens over an unencrypted channel.
    .EXAMPLE
    Test-MtEntraAgentBlueprintRedirectUriHygiene
    .LINK
    https://maester.dev/docs/commands/Test-MtEntraAgentBlueprintRedirectUriHygiene
    .LINK
    https://learn.microsoft.com/graph/api/agentidentityblueprint-list?view=graph-rest-1.0
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Reading Agent Identity Blueprints with redirect URI metadata.'
        $Blueprints = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId', 'web')
        )

        Write-Verbose "Found $($Blueprints.Count) Agent Identity Blueprints."

        if ($Blueprints.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Identity Blueprints were found in the tenant.'
            )
            return $true
        }

        $RedirectFindings = [System.Collections.Generic.List[pscustomobject]]::new()

        foreach ($Blueprint in $Blueprints) {
            $BlueprintId = [string]$Blueprint.id
            $DisplayName = [string]$Blueprint.displayName
            $AppId = [string]$Blueprint.appId
            $RedirectUris = @($Blueprint.web.redirectUris)

            foreach ($Uri in $RedirectUris) {
                $UriString = [string]$Uri
                if ([string]::IsNullOrWhiteSpace($UriString)) { continue }

                if ($UriString -match '\*') {
                    $RedirectFindings.Add([pscustomobject]@{
                        BlueprintId = $BlueprintId
                        DisplayName = $DisplayName
                        AppId       = $AppId
                        Uri         = $UriString
                        Issue       = 'Wildcard redirect URI: tokens can be redirected to any host matching the pattern.'
                    })
                    continue
                }

                $ParsedUri = $null
                if ([System.Uri]::TryCreate($UriString, [System.UriKind]::Absolute, [ref]$ParsedUri)) {
                    if ($ParsedUri.Scheme -eq 'http' -and !$ParsedUri.IsLoopback) {
                        $RedirectFindings.Add([pscustomobject]@{
                            BlueprintId = $BlueprintId
                            DisplayName = $DisplayName
                            AppId       = $AppId
                            Uri         = $UriString
                            Issue       = 'Plain-http, non-loopback redirect URI: tokens are returned over an unencrypted channel.'
                        })
                    }
                }
            }
        }

        if ($RedirectFindings.Count -eq 0) {
            Add-MtTestResultDetail -Result (
                'Well done. No Agent Identity Blueprint has a wildcard or plain-http redirect URI.'
            )
            return $true
        }

        $HasWildcard = @($RedirectFindings | Where-Object { $_.Issue -like 'Wildcard*' }).Count -gt 0
        $Severity = if ($HasWildcard) { 'High' } else { 'Medium' }

        $Result = "Found $($RedirectFindings.Count) unsafe redirect URI(s) across Agent Identity Blueprints."
        $Result += "`n`n| Blueprint object ID | Display name | App ID | Redirect URI | Issue |"
        $Result += "`n| --- | --- | --- | --- | --- |"
        foreach ($Item in $RedirectFindings) {
            $Name = [string]$Item.DisplayName
            if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
            $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
            $Name = $Name -replace "`r?`n", ' '
            $Uri = [System.Net.WebUtility]::HtmlEncode([string]$Item.Uri) -replace '\|', '&#124;'
            $Issue = [System.Net.WebUtility]::HtmlEncode([string]$Item.Issue) -replace '\|', '&#124;'
            $Result += "`n| ``$($Item.BlueprintId)`` | $Name | ``$($Item.AppId)`` | $Uri | $Issue |"
        }

        Add-MtTestResultDetail -Result $Result -Severity $Severity
        return $false
    } catch {
        $ErrorRecord = $_
    }

    if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
    } else {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
    }
    return $null
}
