function Get-MtArgumentCompleterTable {
    <#
    .SYNOPSIS
    Lists the parameters whose values Maester completes with Tab: Command, Parameter, Kind, Values and Narrow.

    .DESCRIPTION
    Register-MtArgumentCompleter registers one completer for each row, and Get-MtArgumentCompletion looks the row
    up to know what to list. Kind names the values (Get-MtCompletionCandidate). Values are a command's own names
    for the Service kind. Narrow is false for a selector whose list does not depend on the other selectors on the
    line: -ExcludeProduct may leave out any product.

    Every Command must be an exported command with the Parameter; the unit tests check each row.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $row = {
        param([string] $Command, [string] $Parameter, [string] $Kind, [string[]] $Values = @(), [bool] $Narrow = $true)
        [pscustomobject]@{ Command = $Command; Parameter = $Parameter; Kind = $Kind; Values = $Values; Narrow = $Narrow }
    }

    # The selectors of a run, and Get-MtTest, which selects the same way.
    & $row 'Invoke-Maester' 'Product' 'Product'
    & $row 'Invoke-Maester' 'ExcludeProduct' 'Product' -Narrow $false
    & $row 'Invoke-Maester' 'Feature' 'Feature'
    & $row 'Invoke-Maester' 'Area' 'Area'
    & $row 'Invoke-Maester' 'Severity' 'Severity'
    & $row 'Invoke-Maester' 'Suite' 'Suite'
    & $row 'Invoke-Maester' 'Tag' 'Tag'
    & $row 'Invoke-Maester' 'ExcludeTag' 'Tag'
    & $row 'Invoke-Maester' 'TestId' 'TestId'
    & $row 'Invoke-Maester' 'ExcludeTestId' 'TestId'
    & $row 'Invoke-Maester' 'Pack' 'Pack'
    & $row 'Get-MtTest' 'Id' 'TestId'
    & $row 'Get-MtTest' 'Tag' 'Tag'
    & $row 'Get-MtTest' 'Product' 'Product'
    & $row 'Get-MtTest' 'Feature' 'Feature'
    & $row 'Get-MtTest' 'Area' 'Area'
    & $row 'Get-MtTest' 'Severity' 'Severity'
    & $row 'Get-MtTest' 'Suite' 'Suite'
    & $row 'Invoke-MtTest' 'Id' 'TestId'

    # Writing a test: the keys the taxonomy allows, whatever tests exist.
    & $row 'New-MtTest' 'Product' 'TaxonomyProduct'
    & $row 'New-MtTest' 'Feature' 'TaxonomyFeature'
    & $row 'New-MtTest' 'Area' 'TaxonomyArea'
    & $row 'New-MtTest' 'ResourceType' 'ResourceType'
    & $row 'New-MtTest' 'Mitre' 'Mitre'
    & $row 'New-MtTest' 'Service' 'TestService'

    # Packs: Invoke-Maester -Pack takes a code or an ID; the pack commands take IDs.
    & $row 'Get-MtPack' 'Id' 'PackId'
    & $row 'Restore-MtPack' 'Id' 'InstalledPackId'
    & $row 'Update-MtPack' 'Id' 'InstalledPackId'
    & $row 'Uninstall-MtPack' 'Id' 'InstalledPackId'

    # Connections: each command's own service names (as its Resolve-MtRequestedService call has them), then the
    # services of pack connectors.
    & $row 'Connect-Maester' 'Service' 'Service' @('ActiveDirectory', 'All', 'Azure', 'Dataverse', 'ExchangeOnline', 'GitHub', 'Graph', 'SecurityCompliance', 'Teams', 'SharePointOnline')
    & $row 'Test-MtConnection' 'Service' 'Service' @('ActiveDirectory', 'All', 'Azure', 'AzureDevOps', 'ExchangeOnline', 'EOP', 'GitHub', 'Graph', 'SecurityCompliance', 'SharePointOnline', 'Teams')
    & $row 'Get-MtConnector' 'Service' 'Service'

    & $row 'Get-MtSetting' 'Name' 'Setting'
    & $row 'Get-MtRoleMember' 'Role' 'Role'
}
