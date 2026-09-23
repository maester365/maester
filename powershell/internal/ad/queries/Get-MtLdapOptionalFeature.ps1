function Get-MtLdapOptionalFeature {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    try {
        $searchBase = "CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,$ConfigurationNamingContext"
        $attributes = @('distinguishedName', 'name', 'msDS-OptionalFeatureGUID', 'msDS-EnabledFeatureBL', 'msDS-RequiredForestBehaviorVersion')
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $searchBase -Scope Subtree -Filter '(objectClass=msDS-OptionalFeature)' -Attributes $attributes)
        return @($entries | ForEach-Object { [PSCustomObject]@{ Name = [string]$_.name; DistinguishedName = [string]$_.DistinguishedName; FeatureGUID = $_.'msDS-OptionalFeatureGUID'; IsEnabled = (@($_.'msDS-EnabledFeatureBL' | Where-Object { $null -ne $_ }).Count -gt 0); RequiredForestBehaviorVersion = $_.'msDS-RequiredForestBehaviorVersion' } })
    }
    catch {
        Write-Verbose "Could not query LDAP optional features: $($_.Exception.Message)"
        return @()
    }
}
