function ConvertTo-MtPackSafeText {
    <#
    .SYNOPSIS
    Cleans text that comes from a pack before Maester prints it (Maester Packs design, section 5.3).

    .DESCRIPTION
    Removes control characters (including the escape that starts a terminal sequence), bidirectional
    formatting characters and other invisible format characters, folds whitespace runs into one space and
    caps the length, so a pack's name, description or file names cannot redraw the install prompt or hide
    what follows. $null and empty text return an empty string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [object] $Text,

        # The longest text returned; longer text is cut and ends with an ellipsis.
        [Parameter()]
        [int] $MaxLength = 200
    )

    if ($null -eq $Text) { return '' }
    $value = [string]$Text
    # Cc: control characters. Cf: format characters, which include the bidirectional overrides and isolates
    # (U+202A-U+202E, U+2066-U+2069), the marks U+200E and U+200F, and zero-width characters.
    $value = [regex]::Replace($value, '[\p{Cc}\p{Cf}  ]', ' ')
    $value = [regex]::Replace($value, '\s+', ' ').Trim()
    if ($MaxLength -gt 1 -and $value.Length -gt $MaxLength) { $value = $value.Substring(0, $MaxLength - 1) + '…' }
    $value
}
