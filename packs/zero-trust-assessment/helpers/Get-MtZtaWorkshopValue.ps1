function Get-MtZtaWorkshopValue {
    <#
    .SYNOPSIS
    Returns a property of an object read from the pack's workshop files, or $null when it has none.
    #>
    [CmdletBinding()]
    param(
        # The object, or $null.
        [Parameter(Position = 0)] [AllowNull()] $InputObject,

        # The property name.
        [Parameter(Mandatory, Position = 1)] [string] $Name
    )

    if ($null -ne $InputObject -and $InputObject.PSObject.Properties[$Name]) { $InputObject.$Name } else { $null }
}
