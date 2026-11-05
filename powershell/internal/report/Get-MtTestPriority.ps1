function Get-MtTestPriority {
    <#
    .SYNOPSIS
    Returns how urgent fixing a test is, the number the report's action plan ranks failed tests by.

    .DESCRIPTION
    The engine's copy of priority() in report/src/lib/model.ts (docs/proposals/defenders-path.md, section 6.3), so
    that the defender's path, the console and the Markdown report rank the same way as the report. Severity counts
    most; within a severity, a fix that users won't notice and that costs little comes first, then a test that
    addresses more ATT&CK techniques and maps to more framework requirements:

        severity weight x 4 + ease of UserImpact x 1.5 + ease of ImplementationCost x 1.5
            + min(ATT&CK techniques, 3) x 0.3 + (Control references + 1 when Benchmark is set) x 0.2

    Severity weights are Critical 4, High 3, Medium 2, Low 1 and Info 0, and any other value 2. Ease is Low 2,
    Medium 1 and High 0, and 1 when the attribute is not set. 'None' is not counted as a technique. A row without a
    Severity uses ResultDetail.Severity, as the report does. Keep the two copies the same: a unit test checks the
    numbers.
    #>
    [CmdletBinding()]
    [OutputType([double])]
    param(
        # A result row.
        [Parameter(Mandatory, ValueFromPipeline)] [AllowNull()] [object] $InputObject
    )

    process {
        if ($null -eq $InputObject) { return }
        $value = {
            param($name)
            $property = $InputObject.PSObject.Properties[$name]
            if ($property) { $property.Value } else { $null }
        }
        $severity = [string](& $value 'Severity')
        if (-not $severity) {
            $detail = & $value 'ResultDetail'
            if ($detail -and $detail.PSObject.Properties['Severity']) { $severity = [string]$detail.Severity }
        }
        $severityWeight = @{ Critical = 4; High = 3; Medium = 2; Low = 1; Info = 0 }
        $ease = @{ Low = 2; Medium = 1; High = 0 }
        # Case-sensitive lookups, like the report's.
        $weightOf = { param($table, $key, $default) $key = [string]$key; foreach ($k in $table.Keys) { if ($k -ceq $key) { return $table[$k] } }; $default }

        $mitre = @(& $value 'Mitre' | Where-Object { $_ -and [string]$_ -ne 'None' }).Count
        $control = @(& $value 'Control' | Where-Object { $_ }).Count
        $benchmark = if (& $value 'Benchmark') { 1 } else { 0 }

        [double]((& $weightOf $severityWeight $severity 2) * 4 +
            (& $weightOf $ease (& $value 'UserImpact') 1) * 1.5 +
            (& $weightOf $ease (& $value 'ImplementationCost') 1) * 1.5 +
            [math]::Min($mitre, 3) * 0.3 +
            ($control + $benchmark) * 0.2)
    }
}
