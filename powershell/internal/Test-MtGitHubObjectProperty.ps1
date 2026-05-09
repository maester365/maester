function Test-MtGitHubObjectProperty {
    <#
    .SYNOPSIS
    Internal: Returns true when a GitHub response object includes a property.

    .DESCRIPTION
    Shared readability helper for property-presence checks. It checks the response
    object's property names rather than the property's value, so $false values are
    still treated as present evidence.
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
