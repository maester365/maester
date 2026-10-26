function Get-MtPackConnectorSetting {
    <#
    .SYNOPSIS
    Returns the parameters for a pack connector's Connect function, from -ServiceSetting, the environment and the config (Maester Packs design, section 6.2).

    .DESCRIPTION
    For each parameter of the connector's Connect function, the first value found wins:

    1. -Explicit (Connect-Maester -ServiceSetting);
    2. the environment variable MAESTER_<SERVICE>_<PARAMETER>, the service name in capitals with every other
       character turned into _, for example MAESTER_CNT_GOOGLEWORKSPACE_DOMAIN;
    3. Connections.<Service>.<Parameter> in the Maester config.

    A config file is committed and shared, so a setting whose name says it is a secret (Secret, Password,
    Token, Key, Credential or Certificate in its name) is not read from it, with a warning; pass it with
    -ServiceSetting or an environment variable. An environment value is a string.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)] [string] $Service,
        [Parameter()] [AllowNull()] [object] $RunConfig,
        [Parameter()] [AllowNull()] [System.Collections.IDictionary] $Explicit
    )

    $entry = (Get-MtServiceRegistry).Services[$Service]
    if (-not $entry -or -not $entry.ContainsKey('Pack')) { throw "No installed pack provides the service $Service." }
    $module = Import-MtPackModule -Pack $entry.Pack -PackSet @($script:__MtPackSet)
    $connect = [string]$entry.Connector.Connect
    $names = & $module { param($n) $c = Get-Command -Name $n -CommandType Function -ErrorAction Stop; @($c.Parameters.Keys) } $connect
    $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    $names = @($names | Where-Object { $_ -notin $common })

    $config = $null
    if ($RunConfig -and $RunConfig.PSObject.Properties['Connections'] -and $RunConfig.Connections) {
        $section = $RunConfig.Connections.PSObject.Properties | Where-Object { $_.Name -eq $Service } | Select-Object -First 1
        if ($section) { $config = $section.Value }
    }
    $prefix = 'MAESTER_' + ($Service.ToUpperInvariant() -replace '[^A-Z0-9]', '_') + '_'
    $secret = '(?i)(secret|password|token|key|credential|certificate)'

    $settings = @{}
    foreach ($name in $names) {
        if ($Explicit -and $Explicit.Contains($name)) { $settings[$name] = $Explicit[$name]; continue }
        $fromEnvironment = [Environment]::GetEnvironmentVariable($prefix + $name.ToUpperInvariant())
        if ($null -ne $fromEnvironment) { $settings[$name] = $fromEnvironment; continue }
        $p = if ($config) { $config.PSObject.Properties | Where-Object { $_.Name -eq $name } | Select-Object -First 1 } else { $null }
        if ($p) {
            if ($name -match $secret) {
                Write-Warning "Connections.$Service.$name in the Maester config looks like a secret and was not used. Pass it with -ServiceSetting, or set $prefix$($name.ToUpperInvariant())."
                continue
            }
            $settings[$name] = $p.Value
        }
    }
    if ($Explicit) {
        foreach ($k in $Explicit.Keys) { if ($k -notin $names) { Write-Warning "The connector of $Service has no setting '$k'; it takes $(if ($names) { $names -join ', ' } else { 'none' })." } }
    }
    $settings
}
