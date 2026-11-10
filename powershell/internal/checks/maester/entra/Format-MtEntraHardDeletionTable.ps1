function Format-MtEntraHardDeletionTable {
    <#
    .SYNOPSIS
    Formats Hard Deletion Protection objects as a Markdown table, capped at a number of rows.

    .DESCRIPTION
    Builds a table with the columns Type, Object ID, Display name and one more column taken from the
    StateProperty. When there are more rows than Limit, the table shows the first Limit rows and a line
    gives the total.

    .PARAMETER InputObject
    The objects to list. Each has Type, Id and DisplayName.

    .PARAMETER StateProperty
    The property shown in the last column, for example Status or State.

    .PARAMETER StateHeading
    The heading of the last column.

    .PARAMETER Limit
    The most rows to show. The default is 25.

    .EXAMPLE
    Format-MtEntraHardDeletionTable -InputObject $Rows -StateProperty Status -StateHeading Status
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object[]] $InputObject,

        [Parameter(Mandatory)]
        [string] $StateProperty,

        [Parameter(Mandatory)]
        [string] $StateHeading,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int] $Limit = 25
    )

    $Table = "| Type | Object ID | Display name | $StateHeading |`n| --- | --- | --- | --- |"
    foreach ($Row in @($InputObject | Select-Object -First $Limit)) {
        $DisplayName = [System.Net.WebUtility]::HtmlEncode([string]$Row.DisplayName) -replace '\|', '&#124;'
        $Table += "`n| $($Row.Type) | $($Row.Id) | $DisplayName | $($Row.$StateProperty) |"
    }
    if (@($InputObject).Count -gt $Limit) {
        $Table += "`n`nShowing the first $Limit of $(@($InputObject).Count) objects."
    }
    $Table
}
