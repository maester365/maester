function Get-MtSetting {
    <#
    .SYNOPSIS
    Returns a setting from GlobalSettings in the Maester config.

    .DESCRIPTION
    The value comes from GlobalSettings in the run config; when the config does not set it, the default
    from the settings registry is returned, else the -Default value.

    A test that ships with Maester does not call this command for a value it checks against: it declares a
    parameter bound to the setting, [MaesterParameter(Setting = 'ParkedDomains')], so the value shows in
    Get-MtTest and a TestSettings row can override it. Connect commands, data helpers, packs and custom tests
    call it. When a native test is running, the name of each setting read is recorded on that test's result
    (SettingsRead), so the result shows every setting the test depended on.

    .PARAMETER Name
    The name of the setting, for example EmergencyAccessAccounts. Test packs can use Namespace.Key names.

    .PARAMETER Default
    The value to return when neither the config nor the settings registry has one.

    .EXAMPLE
    Get-MtSetting -Name EmergencyAccessAccounts

    Returns the emergency access accounts configured for the run.

    .LINK
    https://maester.dev/docs/commands/Get-MtSetting
    #>
    [Alias('Get-MtMaesterConfigGlobalSetting')]
    [CmdletBinding()]
    [OutputType([object], [object[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('SettingName')]
        [string] $Name,

        [Parameter()]
        [AllowNull()]
        [object] $Default
    )

    $registry = (Get-MtSettingRegistry).Settings

    # Record the read on the native test that is running, so its result names every setting it depended on.
    $currentTest = [Maester.Engine.MtSession]::GetCurrentTest()
    if ($currentTest -and $__MtSession) {
        if (-not $__MtSession.SettingRead) { $__MtSession.SettingRead = @{} }
        if (-not $__MtSession.SettingRead.ContainsKey($currentTest)) { $__MtSession.SettingRead[$currentTest] = [System.Collections.Generic.List[string]]::new() }
        if ($Name -notin $__MtSession.SettingRead[$currentTest]) { $__MtSession.SettingRead[$currentTest].Add($Name) }
    }

    $globalSettings = if ($__MtSession -and $__MtSession.MaesterConfig -and $__MtSession.MaesterConfig.PSObject.Properties['GlobalSettings']) { $__MtSession.MaesterConfig.GlobalSettings } else { $null }
    if ($globalSettings -and $globalSettings.PSObject.Properties[$Name]) {
        $value = $globalSettings.$Name
        $shown = if ($registry.ContainsKey($Name) -and $registry[$Name].Sensitive) { '[redacted]' } else { $value | ConvertTo-Json -Depth 5 -Compress }
        Write-Verbose "Maester setting `"$Name`": $shown"
        return $value
    }
    if ($registry.ContainsKey($Name) -and $null -ne $registry[$Name].Default) {
        # Arrays are returned with the comma operator so an empty default stays an empty array.
        return , $registry[$Name].Default
    }
    $Default
}
