function ConvertTo-MtLdapFilterValue {
    <#
    .SYNOPSIS
    Escapes an LDAP filter assertion value.
    .DESCRIPTION
    Encodes strings as UTF-8 bytes and escapes LDAP filter metacharacters and non-ASCII bytes.
    Binary values are escaped byte by byte. GUIDs use AD objectGUID byte order.
    Pass byte arrays with -Value (or wrap them with a unary comma in a pipeline to prevent enumeration).
    This escapes values only, not entire filters, attribute names or distinguished names (DN syntax).
    .PARAMETER Value
    A string, byte array or GUID to use as an LDAP filter assertion value. Null becomes an empty value.
    .EXAMPLE
    $value = ConvertTo-MtLdapFilterValue 'Smith (Admin)*'
    Invoke-MtADQuery -Filter "(displayName=$value)" -Attributes displayName

    Searches for the literal name, without treating its parentheses or asterisk as filter syntax.
    .LINK
    https://maester.dev/docs/commands/ConvertTo-MtLdapFilterValue
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [object] $Value
    )
    process {
        Write-Verbose 'Encoding an LDAP filter assertion value without logging its contents.'
        $binary = $Value -is [byte[]] -or $Value -is [guid]
        $bytes = if ($Value -is [guid]) { $Value.ToByteArray() }
        elseif ($Value -is [byte[]]) { $Value }
        elseif ($null -eq $Value -or $Value -is [string]) { [System.Text.Encoding]::UTF8.GetBytes([string]$Value) }
        else { throw 'Value must be a string, byte array or GUID.' }

        $builder = [System.Text.StringBuilder]::new()
        foreach ($b in $bytes) {
            if ($binary -or $b -in 0, 40, 41, 42, 92 -or $b -lt 32 -or $b -ge 127) {
                [void]$builder.Append(('\{0:x2}' -f $b))
            } else {
                [void]$builder.Append([char]$b)
            }
        }
        return $builder.ToString()
    }
}
