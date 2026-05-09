function Test-MtGitHubObjectProperty {
    <#
    .SYNOPSIS
    Internal: Returns true when a GitHub response object includes a property.

    .DESCRIPTION
    Checks property presence rather than truthiness so an API field whose value is
    $false is still treated as present evidence.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory = $true)]
        [string] $PropertyName
    )

    if ($null -eq $InputObject) { return $false }
    return $InputObject.PSObject.Properties.Name -contains $PropertyName
}
