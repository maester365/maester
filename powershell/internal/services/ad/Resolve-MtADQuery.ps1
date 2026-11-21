function Resolve-MtADQuery {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object] $Query)

    $parameters = @{}
    $names = if ($Query -is [System.Collections.IDictionary]) { @($Query.Keys) }
    elseif ($Query -is [System.Management.Automation.PSCustomObject]) { @($Query.PSObject.Properties.Name) }
    else { throw 'Query must be a query definition, dictionary or PSCustomObject.' }
    foreach ($name in $names) {
        if ($name -eq 'PSTypeName') { continue }
        if ($name -notin 'Name', 'SearchBase', 'NamingContext', 'Scope', 'Filter', 'Attributes', 'SecurityDescriptorFlags') {
            throw 'Query contains an unsupported field.'
        }
        $value = if ($Query -is [System.Collections.IDictionary]) { $Query[$name] } else { $Query.$name }
        if ($name -in 'SearchBase', 'NamingContext' -and $null -eq $value) { continue }
        $parameters[$name] = $value
    }
    return New-MtADQuery @parameters
}
