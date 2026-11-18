function ConvertTo-MtCommandParameterValue {
    <#
    .SYNOPSIS
    Renders one bound parameter value for the recorded Invoke-Maester command string.

    .DESCRIPTION
    Strings are quoted and value types are written as they are. Anything else is rendered as
    its type name in angle brackets, never its content: interpolating an arbitrary object calls
    that object's own ToString(), and a type supplied by the caller can use that to place its
    contents - a connection string, an API key, a token - into a command string that is stored
    in the result file and shown in the report.

    A $null element inside an array renders as an empty string, matching what the previous
    inline join produced.

    .EXAMPLE
    ConvertTo-MtCommandParameterValue -Value 'Entra'

    Returns 'Entra' in quotes.

    .EXAMPLE
    ConvertTo-MtCommandParameterValue -Value $config

    Returns <PSCustomObject> rather than whatever $config says about itself.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return "'$Value'" }
    if ($Value -is [ValueType]) { return "$Value" }

    if ($Value -is [array]) {
        $items = @($Value | ForEach-Object {
                if ($null -eq $_) { '' }
                elseif ($_ -is [string] -or $_ -is [ValueType]) { "$_" }
                else { "<$($_.GetType().Name)>" }
            })
        return "@('$($items -join "', '")')"
    }

    return "<$($Value.GetType().Name)>"
}
