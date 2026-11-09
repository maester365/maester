function Format-MtAdSummaryTable {
    <#
    .SYNOPSIS
    Formats ordered scalar assessment metrics as an escaped Markdown table.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Values)

    $rows = @('| Metric | Value |', '| --- | --- |')
    foreach ($name in $Values.Keys) {
        $rows += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $name), (Format-MtAdSiteInventoryValue $Values[$name])
    }
    return $rows -join "`n"
}
