function Test-MtGlobalSetting {
    <#
    .SYNOPSIS
    Checks GlobalSettings of the run config against the settings registry, once, before a run.

    .DESCRIPTION
    Returns Errors and Warnings (lists of messages).

    - A registered setting whose value has the wrong type, is not one of its AllowedValues, does not fit its
      Kind, or holds a list item that lacks a required property or has a value its Items does not allow is
      an error. A property of a list item that Items does not name is a warning. Without this check a wrong value
      is reported once by every test that binds the setting, or not at all by a helper that reads it.
    - A key without a dot that is not registered is a warning: built-in settings are all registered and the
      settings of packs and custom tests are named Namespace.Key, so it is a typo or a 2.x key of the
      user's own tests. The message names the closest registered setting.
    - A Namespace.Key that no pack in the run declares passes through.
    - A null value means "not set" and is skipped, as the engine skips it when it binds parameters.

    .EXAMPLE
    Test-MtGlobalSetting -GlobalSetting $runConfig.GlobalSettings

    Returns the problems of the GlobalSettings section, if any.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The GlobalSettings section: an object or a hashtable.
        [Parameter()] [AllowNull()] [object] $GlobalSetting
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $out = { [pscustomobject]@{ Errors = [string[]]$errors; Warnings = [string[]]$warnings } }
    if ($null -eq $GlobalSetting) { return & $out }

    $registry = (Get-MtSettingRegistry).Settings
    $kinds = Get-MtParameterKindRegistry
    $isObject = { param($v) $v -is [System.Collections.IDictionary] -or $v -is [System.Management.Automation.PSCustomObject] }
    $read = {
        param($object)
        if ($object -is [System.Collections.IDictionary]) { foreach ($k in $object.Keys) { [pscustomobject]@{ Name = [string]$k; Value = $object[$k] } } }
        else { foreach ($p in $object.PSObject.Properties) { [pscustomobject]@{ Name = $p.Name; Value = $p.Value } } }
    }
    # Edit distance, to name the setting a mistyped key most likely means.
    $distance = {
        param([string] $a, [string] $b)
        $a = $a.ToLowerInvariant(); $b = $b.ToLowerInvariant()
        $previous = 0..$b.Length
        for ($i = 1; $i -le $a.Length; $i++) {
            $current = @($i) + @(0) * $b.Length
            for ($j = 1; $j -le $b.Length; $j++) {
                $cost = if ($a[$i - 1] -eq $b[$j - 1]) { 0 } else { 1 }
                $current[$j] = [math]::Min([math]::Min($current[$j - 1] + 1, $previous[$j] + 1), $previous[$j - 1] + $cost)
            }
            $previous = $current
        }
        $previous[$b.Length]
    }

    foreach ($setting in @(& $read $GlobalSetting)) {
        $name = $setting.Name
        $value = $setting.Value
        if (-not $registry.ContainsKey($name)) {
            if ($name -notmatch '\.') {
                $closest = $registry.Keys | Where-Object { $_ -notmatch '\.' } |
                    ForEach-Object { [pscustomobject]@{ Name = $_; Distance = (& $distance $name $_) } } |
                    Where-Object { $_.Distance -le [math]::Max(2, [int]($name.Length / 4)) } | Sort-Object Distance, Name | Select-Object -First 1
                $hint = if ($closest) { " Did you mean '$($closest.Name)'?" } else { '' }
                $warnings.Add("GlobalSettings has '$name', which is not a Maester setting, so no built-in test reads it.$hint A setting of your own tests needs a Namespace.Key name, for example Contoso.$name.")
            }
            continue
        }
        if ($null -eq $value) { continue }
        $entry = $registry[$name]

        if ($entry.Type -eq 'object') {
            if (-not (& $isObject $value)) { $errors.Add("GlobalSettings.$name`: expected an object.") }
            continue
        }
        $converted = ConvertTo-MtParameterValue -Kinds $kinds -Value $value -Parameter ([pscustomobject]@{
                Name = $name; Type = $entry.Type; Range = $null
                AllowedValues = if ($entry.ContainsKey('AllowedValues')) { $entry.AllowedValues } else { $null }
                Kind = if ($entry.ContainsKey('Kind')) { $entry.Kind } else { $null }
            })
        if ($converted.Error) { $errors.Add("GlobalSettings.$name`: $($converted.Error)"); continue }

        if ($entry.Type -eq 'object[]' -and $entry.ContainsKey('Items') -and $entry.Items) {
            $properties = $entry.Items.Properties
            $requireAny = @($entry.Items.RequireAny | Where-Object { $_ })
            $index = 0
            foreach ($item in @($converted.Value)) {
                $index++
                $fields = @(& $read $item)
                foreach ($field in $fields) {
                    if ($properties -and -not $properties.ContainsKey($field.Name)) {
                        $warnings.Add("GlobalSettings.$name, item $index`: '$($field.Name)' is ignored. An item has $(($properties.Keys | Sort-Object) -join ', ').")
                    } elseif ($properties -and $properties[$field.Name] -and $null -ne $field.Value -and -not ($properties[$field.Name] | Where-Object { $_ -eq $field.Value })) {
                        $errors.Add("GlobalSettings.$name, item $index`: $($field.Name) '$($field.Value)' is not one of $($properties[$field.Name] -join ', ').")
                    }
                }
                if ($requireAny.Count -gt 0 -and -not ($fields | Where-Object { $_.Name -in $requireAny -and -not [string]::IsNullOrWhiteSpace([string]$_.Value) })) {
                    $errors.Add("GlobalSettings.$name, item $index`: needs $($requireAny -join ' or ').")
                }
            }
        }
    }
    & $out
}

function Assert-MtGlobalSetting {
    <#
    .SYNOPSIS
    Writes the warnings of Test-MtGlobalSetting and throws on its errors, naming the config source.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $RunConfig
    )
    $check = Test-MtGlobalSetting -GlobalSetting $RunConfig.GlobalSettings
    foreach ($warning in $check.Warnings) { Write-Warning $warning }
    if ($check.Errors.Count -gt 0) {
        $source = if ($RunConfig.PSObject.Properties['ConfigSource'] -and $RunConfig.ConfigSource) { " ($($RunConfig.ConfigSource))" } else { '' }
        throw "The Maester config$source has $($check.Errors.Count) invalid setting$(if ($check.Errors.Count -ne 1) { 's' }): $($check.Errors -join ' ')"
    }
}
