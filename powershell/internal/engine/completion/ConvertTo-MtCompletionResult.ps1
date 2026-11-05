function ConvertTo-MtCompletionResult {
    <#
    .SYNOPSIS
    Makes a CompletionResult for a parameter value, quoting the value when the command line needs it.

    .DESCRIPTION
    A value the user started in quotes keeps that quote. Otherwise a value is put in single quotes when it has
    whitespace or a character the parser would read as syntax, or starts with '-'. Dots, hyphens, colons and
    '*' need no quotes: CISA.MS.AAD.3.1, MT.1024.* and cis-m365:5.1.5.1 are each one string argument.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CompletionResult])]
    param(
        [Parameter(Mandatory)] [string] $Value,
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $ListItemText,
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $ToolTip,
        # The quote the user typed before the word: ' or ".
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $Quote
    )

    $text = if ($Quote -eq '"') {
        '"' + ($Value -replace '([`$"])', '`$1') + '"'
    } elseif ($Quote -eq "'" -or $Value -match '[\s,;(){}\[\]@$#`''"|&<>]' -or $Value.StartsWith('-')) {
        "'" + [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Value) + "'"
    } else {
        $Value
    }
    $item = if ([string]::IsNullOrWhiteSpace($ListItemText)) { $Value } else { $ListItemText }
    $tip = if ([string]::IsNullOrWhiteSpace($ToolTip)) { $Value } else { $ToolTip }
    [System.Management.Automation.CompletionResult]::new($text, $item, 'ParameterValue', $tip)
}
