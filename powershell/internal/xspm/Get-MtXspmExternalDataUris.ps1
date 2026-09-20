function Get-MtXspmExternalDataUris {
    <#
    .SYNOPSIS
    Gets the validated external data sources used by XSPM hunting queries.

    .DESCRIPTION
    Returns the built-in XSPM data sources, allowing an organization to point
    Advanced Hunting at HTTPS mirrors through the XspmExternalDataUris global
    setting. The values are inserted into KQL externaldata literals, so they
    are validated before they are used in a query.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    $Uris = [ordered]@{
        EntraDirectoryRoles = 'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json'
        MicrosoftApps       = 'https://raw.githubusercontent.com/merill/microsoft-info/main/_info/MicrosoftApps.json'
        ApiPermissions      = 'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_ApiPermissions.json'
        ArmApiRequests      = 'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/refs/heads/main/PrivilegedOperations/ArmApiRequest.csv'
    }

    $ConfiguredUris = Get-MtMaesterConfigGlobalSetting -SettingName 'XspmExternalDataUris' -Verbose:$false
    if ($null -ne $ConfiguredUris) {
        foreach ($Name in @($Uris.Keys)) {
            $HasConfiguredValue = $false
            $ConfiguredValue = $null

            if ($ConfiguredUris -is [System.Collections.IDictionary]) {
                if ($ConfiguredUris.Contains($Name)) {
                    $ConfiguredValue = $ConfiguredUris[$Name]
                    $HasConfiguredValue = $true
                }
            } else {
                $ConfiguredProperty = $ConfiguredUris.PSObject.Properties[$Name]
                if ($null -ne $ConfiguredProperty) {
                    $ConfiguredValue = $ConfiguredProperty.Value
                    $HasConfiguredValue = $true
                }
            }

            if ($HasConfiguredValue) {
                $Uris[$Name] = [string]$ConfiguredValue
            }
        }
    }

    foreach ($Entry in $Uris.GetEnumerator()) {
        $Value = [string]$Entry.Value
        $ParsedUri = $null

        if ([string]::IsNullOrWhiteSpace($Value) -or
            -not [System.Uri]::TryCreate($Value, [System.UriKind]::Absolute, [ref]$ParsedUri) -or
            $ParsedUri.Scheme -ne 'https' -or
            -not [string]::IsNullOrEmpty($ParsedUri.UserInfo) -or
            -not [string]::IsNullOrEmpty($ParsedUri.Fragment) -or
            [string]::IsNullOrWhiteSpace($ParsedUri.Host) -or
            $Value -match "['\[\]\r\n]") {
            throw "XSPM external data source '$($Entry.Key)' must be an absolute HTTPS URI without user information, fragments, quotes, brackets, or line breaks."
        }
    }

    return $Uris
}
