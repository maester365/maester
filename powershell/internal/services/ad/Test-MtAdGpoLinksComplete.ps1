function Test-MtAdGpoLinksComplete {
    <#
    .SYNOPSIS
    Checks whether a GPO state's link-completeness signal is conclusive.
    .DESCRIPTION
    Older state objects without a signal retain compatibility. A present signal
    must be the Boolean value true; null, strings and false are inconclusive.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][object] $State)

    if ($null -eq $State) { return $false }
    if ($State -is [System.Collections.IDictionary]) {
        if (-not $State.Contains('GPOLinksComplete')) { return $true }
        $value = $State['GPOLinksComplete']
    }
    else {
        $property = $State.PSObject.Properties['GPOLinksComplete']
        if ($null -eq $property) { return $true }
        $value = $property.Value
    }
    return ($value -is [bool] -and $value)
}
