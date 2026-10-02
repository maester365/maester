function Write-MtConnectionSummary {
    <#
    .SYNOPSIS
    Prints a table of the services Connect-Maester tried to connect to.

    .DESCRIPTION
    Shows one row per service with its status and a short detail, in a fixed order with Microsoft Graph first.
    When any service did not connect, adds a hint to run Connect-Maester with -Verbose for the full messages.

    .EXAMPLE
    Write-MtConnectionSummary -Connection $connectionSummary.Values
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    param(
        # Objects with Service, Status and Details properties, one per service.
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]] $Connection
    )

    if ($Connection.Count -eq 0) { return }

    $serviceOrder = 'Graph', 'Azure', 'Dataverse', 'ExchangeOnline', 'SecurityCompliance', 'Teams', 'SharePointOnline', 'GitHub', 'ActiveDirectory'
    $displayNames = @{
        ActiveDirectory    = 'Active Directory'
        Azure              = 'Azure'
        Dataverse          = 'Dataverse'
        ExchangeOnline     = 'Exchange Online'
        GitHub             = 'GitHub'
        Graph              = 'Microsoft Graph'
        SecurityCompliance = 'Security & Compliance'
        SharePointOnline   = 'SharePoint Online'
        Teams              = 'Microsoft Teams'
    }
    $statusColors = @{
        'Connected'     = 'Green'
        'Skipped'       = 'Yellow'
        'Failed'        = 'Red'
        'Not installed' = 'Red'
    }
    # Error messages can be long or multi-line. The full text is written to the verbose stream.
    $maxDetailsLength = 100

    $rows = foreach ($item in ($Connection | Sort-Object { $index = [array]::IndexOf($serviceOrder, $_.Service); if ($index -lt 0) { $serviceOrder.Count } else { $index } })) {
        $details = ([string]$item.Details -replace '\s*[\r\n]+\s*', ' ').Trim()
        if ($details.Length -gt $maxDetailsLength) {
            $details = $details.Substring(0, $maxDetailsLength - 3) + '...'
        }
        [PSCustomObject]@{
            Service = if ($displayNames.ContainsKey($item.Service)) { $displayNames[$item.Service] } else { [string]$item.Service }
            Status  = [string]$item.Status
            Details = $details
        }
    }

    $serviceWidth = [Math]::Max('Service'.Length, ($rows.Service | Measure-Object -Property Length -Maximum).Maximum) + 2
    $statusWidth = [Math]::Max('Status'.Length, ($rows.Status | Measure-Object -Property Length -Maximum).Maximum) + 2

    Write-Host
    Write-Host ('Service'.PadRight($serviceWidth) + 'Status'.PadRight($statusWidth) + 'Details')
    Write-Host ('-------'.PadRight($serviceWidth) + '------'.PadRight($statusWidth) + '-------')
    foreach ($row in $rows) {
        $statusColor = if ($statusColors.ContainsKey($row.Status)) { $statusColors[$row.Status] } else { 'Gray' }
        Write-Host $row.Service.PadRight($serviceWidth) -NoNewline
        Write-Host $row.Status.PadRight($statusWidth) -NoNewline -ForegroundColor $statusColor
        Write-Host $row.Details
    }
    Write-Host

    if ($rows | Where-Object { $_.Status -ne 'Connected' }) {
        Write-Host 'For details, run Connect-Maester again with -Verbose.' -ForegroundColor DarkGray
        Write-Host
    }
}
