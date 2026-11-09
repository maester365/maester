function Get-MtAdStateCollection {
    <#
    .SYNOPSIS
    Reads a required collection from a dictionary or object AD snapshot.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)] [AllowNull()] [object] $State,
        [Parameter(Mandatory)] [string] $Name
    )

    $present = $false
    $value = $null
    if ($null -ne $State) {
        if ($State -is [System.Collections.IDictionary]) {
            $present = $State.Contains($Name)
            if ($present) { $value = $State[$Name] }
        } else {
            $property = $State.PSObject.Properties[$Name]
            $present = $null -ne $property
            if ($present) { $value = $property.Value }
        }
    }
    if (-not $present -or $null -eq $value) {
        throw "Active Directory $Name data is unavailable."
    }
    # Preserve an empty collected array as a value, rather than emitting no output.
    return ,@($value)
}
