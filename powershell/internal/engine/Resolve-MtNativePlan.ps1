function Resolve-MtNativePlan {
    <#
    .SYNOPSIS
    Decides, for every native test, whether it runs and if not why (design stages 5 and 6).

    .DESCRIPTION
    Gates apply in this order, and the first failing gate gives the reason (design section 6):
    invalid metadata; disabled by config; selection (IDs, tags, Preview, long-running, opt-in service);
    platform; tenant type; cloud; service; licence; parameter binding.

    Each plan row has: Test, Disposition (Run, NotRun, Skipped or Error), ReasonCode, ReasonDetail,
    LegacySkipCode, Parameters (the bound hashtable), EffectiveParameters, TimeoutSeconds, Setting (the
    TestSettings row), InstancePatterns (for a family selected by instance ID) and ExactlyNamed.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Test,
        [Parameter(Mandatory)] [pscustomobject] $Selection,
        [Parameter(Mandatory)] [pscustomobject] $RunConfig,
        [Parameter()] [AllowNull()] [pscustomobject] $TenantContext,
        # The include and exclude tags of the run, and which exclusions the engine added by default.
        [Parameter()] [string[]] $IncludeTag = @(),
        [Parameter()] [string[]] $ExcludeTag = @(),
        [Parameter()] [string[]] $AutoExcludedTag = @(),
        # Parameter values that win over the config (Invoke-MtTest -Parameter), by test ID.
        [Parameter()] [hashtable] $ParameterOverride = @{},
        [Parameter()] [switch] $DryRun
    )

    $environment = if ($RunConfig.PSObject.Properties['Environment']) { $RunConfig.Environment } else { $null }
    $enforce = @{ Service = $true; License = $true; TenantType = $false; Cloud = $false }
    if ($environment -and $environment.PSObject.Properties['Enforce'] -and $environment.Enforce) {
        foreach ($p in $environment.Enforce.PSObject.Properties) { if ($enforce.ContainsKey($p.Name)) { $enforce[$p.Name] = [bool]$p.Value } }
    }
    $execution = if ($RunConfig.PSObject.Properties['Execution']) { $RunConfig.Execution } else { $null }
    $registry = Get-MtServiceRegistry
    # Allow-list mode needs the rows that enable a test. Read them once, not once per test: a config copied
    # from 2.x has hundreds of rows.
    $allowListIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($Selection.DefaultAction -eq 'Skip') {
        foreach ($ts in @($RunConfig.TestSettings)) {
            if ($ts -and $ts.Id -and $ts.PSObject.Properties['Enabled'] -and $ts.Enabled -eq $true) { $null = $allowListIds.Add([string]$ts.Id) }
        }
    }

    foreach ($t in $Test) {
        $row = [ordered]@{
            Test                = $t
            Disposition         = 'Run'
            ReasonCode          = $null
            ReasonDetail        = $null
            LegacySkipCode      = $null
            Parameters          = @{}
            EffectiveParameters = @()
            TimeoutSeconds      = 0
            Setting             = $null
            InstancePatterns    = @()
            ExactlyNamed        = $false
        }
        $set = { param($disposition, $code, $detail, $legacy) $row.Disposition = $disposition; $row.ReasonCode = $code; $row.ReasonDetail = $detail; $row.LegacySkipCode = $legacy }

        # Invalid metadata, load failures, duplicates, newer engine required.
        if ($t.Errors -and $t.Errors.Count -gt 0) {
            $first = $t.Errors[0]
            $location = if ($t.File) { " ($([System.IO.Path]::GetFileName($t.File)), line $($first.Line))" } else { '' }
            & $set 'Error' $first.Code "$($first.Message)$location"
            [pscustomobject]$row; continue
        }

        $isFamily = [bool]$t.InstanceSource
        $setting = Get-MtTestSetting -RunConfig $RunConfig -Id $t.Id
        $row.Setting = $setting

        # Config admission.
        if ($setting -and $setting.PSObject.Properties['Enabled'] -and $setting.Enabled -eq $false) {
            & $set 'NotRun' 'DisabledByConfig' $(if ($setting.PSObject.Properties['Reason'] -and $setting.Reason) { [string]$setting.Reason } else { 'Disabled in the Maester config.' })
            [pscustomobject]$row; continue
        }
        # A family is also admitted by a row for one of its instances.
        if ($Selection.DefaultAction -eq 'Skip' -and -not ($allowListIds.Contains([string]$t.Id) -or ($isFamily -and ($allowListIds | Where-Object { $_ -like "$($t.Id).*" })))) {
            & $set 'NotRun' 'NotListed' 'Selection.DefaultAction is Skip and no TestSettings row enables this test.'
            [pscustomobject]$row; continue
        }

        # Selection by ID.
        $excludedBy = @(Test-MtIdMatch -Id $t.Id -Pattern $Selection.ExcludeTestId)
        if (-not $excludedBy -and $isFamily) { $excludedBy = @($Selection.ExcludeTestId | Where-Object { $_.Contains('*') -and "$($t.Id).*" -like $_ }) }
        if ($excludedBy) {
            & $set 'NotRun' 'ExcludedById' "Excluded by ID ($($excludedBy -join ', '))."
            [pscustomobject]$row; continue
        }
        if ($Selection.TestId.Count -gt 0) {
            $includedBy = @(Test-MtIdMatch -Id $t.Id -Pattern $Selection.TestId)
            if (-not $includedBy -and $isFamily) {
                $instancePatterns = @($Selection.TestId | Where-Object { $_ -like "$($t.Id).*" -and -not ($_.Contains('*') -and "$($t.Id).*" -like $_) })
                $wholeFamily = @($Selection.TestId | Where-Object { $_.Contains('*') -and "$($t.Id).*" -like $_ })
                $includedBy = @($wholeFamily) + @($instancePatterns)
                if (-not $wholeFamily) { $row.InstancePatterns = $instancePatterns }
            }
            if (-not $includedBy) {
                & $set 'NotRun' 'NotSelected' 'Not in the list of test IDs to run.'
                [pscustomobject]$row; continue
            }
            $row.ExactlyNamed = [bool]($includedBy | Where-Object { -not $_.Contains('*') })
        }

        # Selection by tag.
        $tags = @($t.EffectiveTag)
        $included = $IncludeTag.Count -eq 0
        if (-not $included) {
            foreach ($tag in $tags) { foreach ($pattern in $IncludeTag) { if ($tag -like $pattern) { $included = $true; break } }; if ($included) { break } }
        }
        if (-not $included) {
            & $set 'NotRun' 'NotSelected' "Matched none of the tags $($IncludeTag -join ', ')."
            [pscustomobject]$row; continue
        }
        $hits = @(foreach ($pattern in $ExcludeTag) { foreach ($tag in $tags) { if ($tag -like $pattern) { $pattern; break } } })
        if ($row.ExactlyNamed) {
            # A test named by its exact ID runs even if it is a preview or long-running test.
            $hits = @($hits | Where-Object { -not ($_ -in 'Preview', 'LongRunning' -and $AutoExcludedTag -contains $_) })
        }
        $optIn = @($t.Service | Where-Object { $registry.Services[$_].OptIn })
        $optInDisconnected = @($optIn | Where-Object { $TenantContext -and $TenantContext.Services.PSObject.Properties[$_] -and -not $TenantContext.Services.$_ })
        if ($optInDisconnected -or ($hits -contains 'AD' -and $AutoExcludedTag -contains 'AD')) {
            & $set 'NotRun' 'OptInServiceNotConnected' 'Active Directory tests run only after Connect-Maester -Service ActiveDirectory.'
            [pscustomobject]$row; continue
        }
        if ($hits) {
            if ($hits -contains 'Preview' -and $AutoExcludedTag -contains 'Preview') { & $set 'NotRun' 'Preview' 'Preview test. Use -IncludePreview to run it.' }
            elseif ($hits -contains 'LongRunning' -and $AutoExcludedTag -contains 'LongRunning') { & $set 'NotRun' 'LongRunning' 'Long-running test. Use -IncludeLongRunning to run it.' }
            else { & $set 'NotRun' 'ExcludedByTag' "Excluded by tag ($(@($hits | Select-Object -Unique) -join ', '))." }
            [pscustomobject]$row; continue
        }

        # Applicability.
        $gate = Test-MtApplicability -Test $t -TenantContext $TenantContext -Enforce $enforce
        if ($gate) {
            & $set 'Skipped' $gate.ReasonCode $gate.ReasonDetail $gate.LegacySkipCode
            [pscustomobject]$row; continue
        }

        # Parameter binding.
        $values = if ($setting -and $setting.PSObject.Properties['Parameters']) { $setting.Parameters } else { $null }
        $override = if ($ParameterOverride.ContainsKey($t.Id)) { $ParameterOverride[$t.Id] } else { $null }
        $binding = ConvertTo-MtTestParameter -Test $t -ConfigValue $values -Override $override
        $row.EffectiveParameters = $binding.Effective
        if ($binding.Error) {
            & $set 'Error' 'InvalidConfiguration' $binding.Error
            [pscustomobject]$row; continue
        }
        $row.Parameters = $binding.Bound

        # Timeout: the test's row, then the long-running default, then the run default. 0 means none.
        $timeout = 0
        if ($execution -and $execution.PSObject.Properties['TestTimeoutSeconds'] -and $execution.TestTimeoutSeconds) { $timeout = [int]$execution.TestTimeoutSeconds }
        # A more specific value set to 0 turns off a broader timeout, so presence (not truthiness) decides.
        if ($t.LongRunning -and $execution -and $execution.PSObject.Properties['LongRunningTimeoutSeconds'] -and $null -ne $execution.LongRunningTimeoutSeconds) { $timeout = [int]$execution.LongRunningTimeoutSeconds }
        if ($setting -and $setting.PSObject.Properties['TimeoutSeconds'] -and $null -ne $setting.TimeoutSeconds) { $timeout = [int]$setting.TimeoutSeconds }
        $row.TimeoutSeconds = $timeout

        if ($DryRun) { & $set 'NotRun' 'DryRun' 'Dry run: this test would have run.' }
        [pscustomobject]$row
    }
}

function Get-MtTestSetting {
    <#
    .SYNOPSIS
    Returns the TestSettings row for a test ID (case-insensitive), or for a family instance its parent's.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $RunConfig,
        [Parameter(Mandatory)] [string] $Id,
        [Parameter()] [string] $ParentId
    )
    $hash = $RunConfig.TestSettingsHash
    if ($hash -and $hash.ContainsKey($Id)) { return $hash[$Id] }
    if ($ParentId -and $hash -and $hash.ContainsKey($ParentId)) { return $hash[$ParentId] }
    $null
}

function Test-MtApplicability {
    <#
    .SYNOPSIS
    Checks platform, tenant type, cloud, service and licence. Returns the first failing gate, or $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $Test,
        [Parameter()] [AllowNull()] [pscustomobject] $TenantContext,
        [Parameter(Mandatory)] [hashtable] $Enforce
    )

    $fail = { param($code, $detail, $legacy) [pscustomobject]@{ ReasonCode = $code; ReasonDetail = $detail; LegacySkipCode = $legacy } }
    $platform = if ($TenantContext) { $TenantContext.Platform } elseif ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'MacOS' } else { 'Linux' }
    if (@($Test.Platform).Count -gt 0 -and $platform -notin $Test.Platform) {
        return & $fail 'PlatformMismatch' "This test runs only on $($Test.Platform -join ', '); this computer runs $platform." 'NotSupported'
    }
    if (-not $TenantContext) { return $null }

    $tenantTypes = if (@($Test.TenantType).Count -gt 0) { @($Test.TenantType) } else { @('Workforce') }
    if ($Enforce.TenantType -and $TenantContext.TenantType -ne 'Unknown' -and $TenantContext.TenantType -notin $tenantTypes) {
        return & $fail 'TenantTypeMismatch' "This test applies to $($tenantTypes -join ', ') tenants; this tenant is $($TenantContext.TenantType)." 'NotSupported'
    }
    if ($Enforce.Cloud -and @($Test.Cloud).Count -gt 0 -and $TenantContext.Cloud -ne 'Unknown' -and $TenantContext.Cloud -notin $Test.Cloud) {
        return & $fail 'CloudMismatch' "This test applies to $($Test.Cloud -join ', '); this tenant is in $($TenantContext.Cloud)." 'NotSupported'
    }

    if ($Enforce.Service) {
        if (@($Test.UnregisteredServices).Count -gt 0) {
            return & $fail 'ServiceNotRegistered' "The service $($Test.UnregisteredServices -join ', ') is not known to this version of Maester." 'NotSupported'
        }
        $registry = Get-MtServiceRegistry
        foreach ($s in @($Test.Service)) {
            $connected = $TenantContext.Services.PSObject.Properties[$s]
            if ($connected -and -not $connected.Value) {
                $legacy = $registry.Services[$s].LegacySkipCode
                $text = Get-MtSkippedReason -SkippedBecause $legacy
                return & $fail 'ServiceNotConnected' $text $legacy
            }
        }
    }

    if ($Enforce.License -and @($Test.License).Count -gt 0 -and $TenantContext.Licenses.State -eq 'Known') {
        if (-not (Test-MtLicenseRequirement -Requirement $Test.License -Licenses $TenantContext.Licenses)) {
            $table = Get-MtLicenseTable
            $firstToken = (@($Test.License)[0] -split '&')[0]
            $legacy = if ($table.Tokens.ContainsKey($firstToken)) { $table.Tokens[$firstToken].LegacySkipCode } else { 'Custom' }
            $detail = "This test requires one of these licences: $($Test.License -join ', ')."
            return & $fail 'LicenseNotFound' $detail $legacy
        }
    }
    $null
}

function Test-MtLicenseRequirement {
    <#
    .SYNOPSIS
    True when the tenant has any one element of a License list; 'A&B' inside an element means all of them.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string[]] $Requirement,
        [Parameter(Mandatory)] [object] $Licenses
    )

    $table = Get-MtLicenseTable
    $planNames = @($Licenses.ServicePlanNames)
    $planIds = @($Licenses.ServicePlanIds)
    $skuIds = @($Licenses.SkuIds)
    foreach ($element in $Requirement) {
        $all = $true
        foreach ($token in ($element -split '&' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            $entry = $null
            foreach ($key in $table.Tokens.Keys) { if ($key -eq $token) { $entry = $table.Tokens[$key] } }
            $has = if ($entry) {
                [bool](@($entry.ServicePlanIds) | Where-Object { $_ -in $planIds }) -or [bool](@($entry.SkuIds) | Where-Object { $_ -in $skuIds }) -or ($planNames -contains $token)
            } else {
                $planNames -contains $token
            }
            if (-not $has) { $all = $false; break }
        }
        if ($all) { return $true }
    }
    $false
}

function Get-MtLicenseTable {
    <#
    .SYNOPSIS
    Returns the licence token table (assets/MaesterLicenseTable.psd1). Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    if (-not $script:__MtLicenseTable) {
        $script:__MtLicenseTable = Import-PowerShellDataFile -Path (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterLicenseTable.psd1')
    }
    $script:__MtLicenseTable
}

function ConvertTo-MtTestParameter {
    <#
    .SYNOPSIS
    Validates parameter values from the config against a test's param() block (design appendix A.5).

    .DESCRIPTION
    Returns Bound (a hashtable to splat), Effective (name, value, source and kind of every parameter) and
    Error (a message, or $null). PowerShell's own binder is too lenient for this: it turns 90.5 into 90
    and accepts abbreviated names, so the engine checks names and types itself.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $Test,
        [Parameter()] [AllowNull()] [object] $ConfigValue,
        [Parameter()] [AllowNull()] [object] $Override
    )

    $bound = @{}
    $sources = @{}
    $errors = [System.Collections.Generic.List[string]]::new()
    $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    $kinds = Get-MtParameterKindRegistry

    $inputs = [System.Collections.Generic.List[object]]::new()
    foreach ($pair in @(@{ Source = 'Config'; Values = $ConfigValue }, @{ Source = 'Parameter'; Values = $Override })) {
        if ($null -eq $pair.Values) { continue }
        $properties = if ($pair.Values -is [System.Collections.IDictionary]) {
            foreach ($k in $pair.Values.Keys) { [pscustomobject]@{ Name = [string]$k; Value = $pair.Values[$k] } }
        } else { $pair.Values.PSObject.Properties | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Value = $_.Value } } }
        foreach ($p in $properties) { $inputs.Add([pscustomobject]@{ Name = $p.Name; Value = $p.Value; Source = $pair.Source }) }
    }

    foreach ($item in $inputs) {
        $parameter = $Test.Parameters | Where-Object { $_.Name -eq $item.Name } | Select-Object -First 1
        if ($item.Name -in $common) { $errors.Add("'$($item.Name)' is a common parameter and cannot be set."); continue }
        if (-not $parameter) { $errors.Add("The test has no parameter '$($item.Name)'."); continue }
        if ($parameter.EngineOwned) { $errors.Add("'$($item.Name)' is supplied by the engine and cannot be set."); continue }
        $converted = ConvertTo-MtParameterValue -Parameter $parameter -Value $item.Value -Kinds $kinds
        if ($converted.Error) { $errors.Add("Parameter '$($parameter.Name)': $($converted.Error)"); continue }
        $bound[$parameter.Name] = $converted.Value
        $sources[$parameter.Name] = $item.Source
    }

    $effective = foreach ($parameter in @($Test.Parameters | Where-Object { -not $_.EngineOwned })) {
        $hasValue = $bound.ContainsKey($parameter.Name)
        [pscustomobject]@{
            Name   = $parameter.Name
            Value  = if ($hasValue) { $bound[$parameter.Name] } else { $parameter.Default }
            Source = if ($hasValue) { $sources[$parameter.Name] } else { 'Default' }
            Kind   = $parameter.Kind
        }
    }

    [pscustomobject]@{
        Bound     = $bound
        Effective = @($effective)
        Error     = if ($errors.Count -gt 0) { $errors -join ' ' } else { $null }
    }
}

function ConvertTo-MtParameterValue {
    <#
    .SYNOPSIS
    Converts one config value to a parameter's type, or returns an error (design appendix A.5).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object] $Parameter,
        [Parameter()] [AllowNull()] [object] $Value,
        [Parameter(Mandatory)] [hashtable] $Kinds
    )

    $result = { param($v, $e) [pscustomobject]@{ Value = $v; Error = $e } }
    # A UI may store { "Id": "...", "DisplayName": "..." }; the test always receives the ID.
    $unwrap = {
        param($v)
        if ($v -is [System.Collections.IDictionary] -and $v.Contains('Id')) { return $v['Id'] }
        if ($v -is [pscustomobject] -and $v.PSObject.Properties['Id']) { return $v.Id }
        if ($v -is [datetime]) { return $v.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture) }
        $v
    }

    switch ($Parameter.Type) {
        'int' {
            if ($Value -is [bool] -or $Value -is [string] -or $null -eq $Value) { return & $result $null 'expected a whole number.' }
            if ($Value -is [double] -or $Value -is [decimal] -or $Value -is [single]) {
                if ([math]::Truncate([double]$Value) -ne [double]$Value) { return & $result $null 'expected a whole number, not a fraction.' }
            }
            try { $number = [long]$Value } catch { return & $result $null 'expected a whole number.' }
            if ($number -lt [int]::MinValue -or $number -gt [int]::MaxValue) { return & $result $null 'the number is out of range.' }
            $converted = [int]$number
        }
        { $_ -in 'bool', 'switch' } {
            if ($Value -isnot [bool]) { return & $result $null 'expected true or false.' }
            $converted = if ($Parameter.Type -eq 'switch') { [switch]$Value } else { [bool]$Value }
        }
        'string' {
            $Value = & $unwrap $Value
            if ($Value -isnot [string]) { return & $result $null 'expected a string.' }
            $converted = $Value
        }
        'string[]' {
            $items = @(foreach ($v in @($Value)) { & $unwrap $v })
            if ($items | Where-Object { $_ -isnot [string] }) { return & $result $null 'expected a string or a list of strings.' }
            $converted = [string[]]$items
        }
        default { return & $result $null "type '$($Parameter.Type)' cannot be set from the config." }
    }

    foreach ($v in @($converted)) {
        if ($Parameter.Range -and ($v -lt $Parameter.Range[0] -or $v -gt $Parameter.Range[1])) {
            return & $result $null "$v is outside the allowed range $($Parameter.Range[0]) to $($Parameter.Range[1])."
        }
        if ($Parameter.AllowedValues -and -not ($Parameter.AllowedValues | Where-Object { $_ -eq $v })) {
            return & $result $null "'$v' is not one of $($Parameter.AllowedValues -join ', ')."
        }
        if ($Parameter.Kind -and $Kinds.Kinds.ContainsKey($Parameter.Kind)) {
            $pattern = $Kinds.Kinds[$Parameter.Kind].Pattern
            if ($pattern -and $v -notmatch $pattern) { return & $result $null "'$v' is not a valid $($Parameter.Kind)." }
        }
    }
    & $result $converted $null
}
