class MtPropertyDifference {
    [string]$PropertyName
    [object]$ExpectedValue
    [object]$ActualValue
    [string]$Description
    [string]$Reason
    MtPropertyDifference([string]$PropertyName, [object]$ExpectedValue, [object]$ActualValue, [string]$Description, [string]$Reason) {
        $this.PropertyName = $PropertyName
        $this.ExpectedValue = $ExpectedValue
        $this.ActualValue = $ActualValue
        $this.Description = $Description
        $this.Reason = $Reason
    }
}

<#
.SYNOPSIS
    Compares two PowerShell objects (typically JSON objects) and returns a list of differences.

.DESCRIPTION
    The Compare-MtJsonObject function recursively compares two objects (such as those imported from JSON)
    and returns an array of differences. It supports comparison of nested objects, arrays, and allows
    exclusion of specific properties via the Settings parameter. The function is useful for configuration
    drift detection, regression testing, or validating changes between baseline and current states.

.PARAMETER Baseline
    The reference object to compare against (e.g., the expected or original state).

.PARAMETER Current
    The object to compare to the baseline (e.g., the actual or new state).

.PARAMETER Path
    (Optional) The property path being compared. Used internally for recursion and reporting.

.PARAMETER Settings
    (Optional) An object that may contain an ExcludeProperties property (array of property names to skip).

.OUTPUTS
    [MtPropertyDifference[]] Returns an array of objects describing each difference found.

.EXAMPLE
    # Compare two JSON files and output the differences
    $baseline = Get-Content -Raw -Path 'baseline.json' | ConvertFrom-Json
    $current = Get-Content -Raw -Path 'current.json' | ConvertFrom-Json
    $diffs = Compare-MtJsonObject -Baseline $baseline -Current $current
    $diffs | Format-Table

.EXAMPLE
    # Exclude specific properties from comparison
    $settings = [PSCustomObject]@{ ExcludeProperties = @('timestamp', 'lastModified') }
    $diffs = Compare-MtJsonObject -Baseline $baseline -Current $current -Settings $settings

.NOTES
    Author: Stephan van Rooij @svrooij
    Date:   2025-06-26

.LINK
    https://maester.dev/docs/commands/Compare-MtJsonObject
#>
function Compare-MtJsonObject {
    [OutputType([MtPropertyDifference[]])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Baseline,
        [Parameter(Mandatory = $true)]
        [object]$Current,
        [Parameter(Mandatory = $false)]
        [string]$Path = "",
        [Parameter(Mandatory = $false)]
        [object]$Settings = $null
    )
    $differences = @()
    # Extract ExcludeProperties from settings if present
    $excludeProperties = @()
    if ($Settings -and $Settings.PSObject.Properties.Match('ExcludeProperties')) {
        $excludeProperties = $Settings.ExcludeProperties
    }

    if ($null -eq $Baseline) {
        $differences += [MtPropertyDifference]::new($Path, $null, $Current, "Baseline is null at path: $Path", "NullBaseline")
        return $differences
    }

    if ($null -eq $Current) {
        $differences += [MtPropertyDifference]::new($Path, $Baseline, $null, "Current is null at path: $Path", "NullCurrent")
        return $differences
    }

    if (-not ($Baseline -is [System.Collections.IDictionary] -or $Baseline -is [PSCustomObject])) {
        return $differences
    }

    $properties = if ($Baseline -is [System.Collections.IDictionary]) { $Baseline.Keys } else { $Baseline.PSObject.Properties.Name }
    foreach ($property in $properties) {
        if ($excludeProperties -contains $property) { continue } # Skip excluded properties
        $currentPath = if ([string]::IsNullOrEmpty($Path)) { $property } else { "$Path.$property" }
        if (($Current -is [System.Collections.IDictionary] -and -not $Current.ContainsKey($property)) -or
            ($Current -is [PSCustomObject] -and -not $Current.PSObject.Properties.Name.Contains($property))) {
            $expected = if ($Baseline -is [System.Collections.IDictionary]) { $Baseline[$property] } else { $Baseline.$property }
            $differences += [MtPropertyDifference]::new($currentPath, $expected, $null, "Property not found: $currentPath", "MissingProperty")
            continue
        }
        $baselineValue = if ($Baseline -is [System.Collections.IDictionary]) { $Baseline[$property] } else { $Baseline.$property }
        $currentValue = if ($Current -is [System.Collections.IDictionary]) { $Current[$property] } else { $Current.$property }
        if ($null -eq $baselineValue -and $null -eq $currentValue) {
            Write-Verbose "Both baseline and current values are null for property: $currentPath"
        }
        elseif ($null -eq $baselineValue -or $null -eq $currentValue) {
            $differences += [MtPropertyDifference]::new($currentPath, $baselineValue, $currentValue, "One of the values is null at path: $currentPath", "NullValue")
        }
        elseif (($baselineValue -is [System.Collections.IDictionary] -or $baselineValue -is [PSCustomObject]) -and
            ($currentValue -is [System.Collections.IDictionary] -or $currentValue -is [PSCustomObject])) {
            $differences += Compare-MtJsonObject -Baseline $baselineValue -Current $currentValue -Path $currentPath -Settings $Settings -ErrorAction SilentlyContinue
        }
        elseif ($baselineValue -is [Array] -and $currentValue -is [Array]) {
            if ($baselineValue.Count -ne $currentValue.Count) {
                $differences += [MtPropertyDifference]::new($currentPath, $baselineValue.Count, $currentValue.Count, "Array size mismatch at $($currentPath)", "ArraySizeMismatch")
            }
            else {
                for ($i = 0; $i -lt $baselineValue.Count; $i++) {
                    $itemPath = "$currentPath[$i]"
                    if (($baselineValue[$i] -is [System.Collections.IDictionary] -or $baselineValue[$i] -is [PSCustomObject]) -and
                        ($currentValue[$i] -is [System.Collections.IDictionary] -or $currentValue[$i] -is [PSCustomObject])) {
                        $differences += Compare-MtJsonObject -Baseline $baselineValue[$i] -Current $currentValue[$i] -Path $itemPath -Settings $Settings -ErrorAction SilentlyContinue
                    }
                    elseif ($baselineValue[$i] -ne $currentValue[$i]) {
                        $differences += [MtPropertyDifference]::new($itemPath, $baselineValue[$i], $currentValue[$i], "Value mismatch at $($itemPath)", "ValueMismatch")
                    }
                }
            }
        }
        elseif ($baselineValue -ne $currentValue) {
            $differences += [MtPropertyDifference]::new($currentPath, $baselineValue, $currentValue, "Value mismatch at $($currentPath)", "ValueMismatch")
        }
    }

    return $differences
}
