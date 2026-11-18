function Format-MtAdUserSecurityTable {
    [CmdletBinding()]
    param(
        [object[]] $Rows,
        [string[]] $Columns
    )

    $lines = @()
    $lines += '| ' + ($Columns -join ' | ') + ' |'
    $lines += '| ' + (($Columns | ForEach-Object { '---' }) -join ' | ') + ' |'
    foreach ($row in $Rows) {
        $values = foreach ($column in $Columns) {
            $value = $row.$column
            if ($null -eq $value) { 'Unknown' } else { ([string]$value -replace '\|', '\|' -replace '[\r\n]+', ' ') }
        }
        $lines += '| ' + ($values -join ' | ') + ' |'
    }
    return ($lines -join "`n")
}
