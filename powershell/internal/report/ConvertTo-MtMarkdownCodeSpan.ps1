function ConvertTo-MtMarkdownCodeSpan {
    <#
    .SYNOPSIS
    Formats text as an inline Markdown code span.

    .DESCRIPTION
    Use this for a tenant value shown as code in test result Markdown, such as a dynamic membership
    rule. Markdown and HTML in a code span are displayed as typed, so the value can't add a link, an
    image or markup to the report. A <code> tag would not work instead: the report shows raw HTML as
    text.

    Line breaks become spaces. The delimiter is one backtick longer than the longest run of backticks
    in the text, and a space pads each side, which the renderer removes, so a backtick at either end
    of the text is kept.

    With -TableCell, every '|' that a backslash does not already escape is escaped as '\|'. In a GFM
    table an escaped pipe stays in the cell, even inside a code span, instead of starting the next
    cell, and the renderer drops the backslash.

    .PARAMETER Text
    The text to format.

    .PARAMETER TableCell
    Escapes '|' so that the code span can go in a Markdown table cell.

    .EXAMPLE
    ConvertTo-MtMarkdownCodeSpan -Text $Group.membershipRule -TableCell

    Returns a membership rule as a code span for a table cell.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Text,

        [switch] $TableCell
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }

    $Text = $Text -replace '\r\n|\r|\n', ' '
    if ($TableCell) {
        # A pipe after an odd number of backslashes is already escaped; any other pipe gets one more.
        $Text = $Text -replace '(\\*)\|', {
            $Backslashes = $_.Groups[1].Value
            if ($Backslashes.Length % 2 -eq 1) { "$Backslashes|" } else { "$Backslashes\|" }
        }
    }

    $LongestRun = 0
    foreach ($Run in [regex]::Matches($Text, '`+')) {
        $LongestRun = [Math]::Max($LongestRun, $Run.Length)
    }
    $Fence = '`' * ($LongestRun + 1)
    return "$Fence $Text $Fence"
}
