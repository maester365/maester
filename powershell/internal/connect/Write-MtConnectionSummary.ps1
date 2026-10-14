function Write-MtConnectionSummary {
    <#
    .SYNOPSIS
        Writes the per-service connection summary shown at the end of Connect-Maester.

    .DESCRIPTION
        Connect-Maester records a status (Connected, Skipped, Failed or Not installed) and a short detail for
        each service it tries. This function prints them as one table, in a fixed service order, followed by a
        hint to rerun with -Verbose for the step-by-step messages.

        Details are reduced to their first line and shortened so that long error messages from the underlying
        modules do not wrap the table. The full messages are written to the verbose stream by Connect-Maester.

    .EXAMPLE
        Write-MtConnectionSummary -Summary @([pscustomobject]@{ Service = 'Microsoft Graph'; Status = 'Connected'; Details = 'user@contoso.com' })

        Prints a one-row connection summary.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colored console summary for interactive use')]
    [CmdletBinding()]
    param (
        # The connection results recorded by Connect-Maester, each with Service, Status and Details.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Summary
    )

    if ($Summary.Count -eq 0) { return }

    $serviceOrder = @('Microsoft Graph', 'Azure', 'Dataverse', 'Exchange Online', 'Security & Compliance', 'Microsoft Teams', 'SharePoint Online', 'GitHub', 'Active Directory')
    $statusColor = @{
        'Connected'     = 'Green'
        'Skipped'       = 'Yellow'
        'Failed'        = 'Red'
        'Not installed' = 'Red'
    }
    $maxDetailLength = 110

    $rows = foreach ($result in $Summary) {
        # Keep the first non-empty line and collapse whitespace so module errors stay on one row.
        $detail = "$($result.Details)" -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1
        $detail = ("$detail" -replace '\s+', ' ').Trim()
        if ($detail.Length -gt $maxDetailLength) {
            $detail = $detail.Substring(0, $maxDetailLength - 3).TrimEnd() + '...'
        }
        $orderIndex = [array]::IndexOf($serviceOrder, $result.Service)
        [pscustomobject]@{
            Order   = if ($orderIndex -ge 0) { $orderIndex } else { $serviceOrder.Count }
            Service = "$($result.Service)"
            Status  = "$($result.Status)"
            Details = $detail
        }
    }
    $rows = @($rows | Sort-Object Order)

    $serviceWidth = [Math]::Max('Service'.Length, ($rows.Service | Measure-Object -Property Length -Maximum).Maximum)
    $statusWidth = [Math]::Max('Status'.Length, ($rows.Status | Measure-Object -Property Length -Maximum).Maximum)

    Write-Host ''
    Write-Host ('{0}  {1}  {2}' -f 'Service'.PadRight($serviceWidth), 'Status'.PadRight($statusWidth), 'Details')
    Write-Host ('{0}  {1}  {2}' -f ('-' * 'Service'.Length).PadRight($serviceWidth), ('-' * 'Status'.Length).PadRight($statusWidth), ('-' * 'Details'.Length))
    foreach ($row in $rows) {
        $color = $statusColor[$row.Status]
        if (-not $color) { $color = 'Gray' }
        Write-Host ('{0}  ' -f $row.Service.PadRight($serviceWidth)) -NoNewline
        Write-Host ('{0}  ' -f $row.Status.PadRight($statusWidth)) -ForegroundColor $color -NoNewline
        Write-Host $row.Details
    }
    Write-Host ''
    Write-Host 'For more details on each connection, run Connect-Maester with -Verbose.' -ForegroundColor DarkGray
}
