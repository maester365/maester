function Get-MtCisaTeamsMeetingPolicies {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'The Teams cmdlet returns a collection of meeting policies.')]
    param(
        [switch]$GlobalOnly
    )

    $policies = if ($GlobalOnly) {
        @(Get-CsTeamsMeetingPolicy -Identity Global -ErrorAction Stop)
    } else {
        @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
    }

    if ($policies.Count -eq 0) {
        throw 'Teams returned no meeting policies.'
    }
    if ($GlobalOnly -and ($policies.Count -ne 1 -or $policies[0].Identity -ne 'Global')) {
        throw 'Teams did not return exactly one Global meeting policy.'
    }

    return $policies
}

function Test-MtCisaTeamsMeetingPolicyBoolean {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SettingName,
        [Parameter(Mandatory)]
        [bool]$ExpectedValue,
        [Parameter(Mandatory)]
        [string]$PolicyDescription
    )

    $policies = Get-MtCisaTeamsMeetingPolicies
    $results = foreach ($policy in $policies) {
        $setting = $policy.PSObject.Properties[$SettingName]
        if ($null -eq $setting -or $setting.Value -isnot [bool]) {
            throw "Teams meeting policy '$($policy.Identity)' did not return a Boolean value for $SettingName."
        }

        [pscustomobject]@{
            Policy = $policy.Identity
            Value  = $setting.Value
            Pass   = $setting.Value -eq $ExpectedValue
        }
    }

    $passed = @($results | Where-Object { -not $_.Pass }).Count -eq 0
    $markdown = if ($passed) {
        "Well done. $PolicyDescription is configured for every meeting policy.`n`n"
    } else {
        "$PolicyDescription is not configured for every meeting policy.`n`n"
    }
    $markdown += "| Policy | $SettingName | Result |`n| --- | --- | --- |`n"
    foreach ($row in $results) {
        $markdown += "| $($row.Policy) | $($row.Value) | $(if ($row.Pass) { 'Pass' } else { 'Fail' }) |`n"
    }
    Add-MtTestResultDetail -Result $markdown.TrimEnd()
    return $passed
}

function Get-MtCisaTeamsGlobalMeetingPolicy {
    [CmdletBinding()]
    param()

    $policies = Get-MtCisaTeamsMeetingPolicies -GlobalOnly
    return $policies[0]
}

function Get-MtCisaTeamsFederationConfiguration {
    [CmdletBinding()]
    param()

    $configurations = @(Get-CsTenantFederationConfiguration -ErrorAction Stop)
    if ($configurations.Count -ne 1) {
        throw 'Teams did not return exactly one tenant federation configuration.'
    }
    return $configurations[0]
}

function Test-MtCisaTeamsIsUSGovernment {
    [CmdletBinding()]
    param()

    $context = Get-MgContext -ErrorAction Stop
    if (-not $context) {
        throw 'A Microsoft Graph context is required to determine the Teams environment.'
    }
    return ($context.Environment -in @('USGov', 'USGovDoD') -or
        $__MtSession.TeamsEnvironmentName -in @('TeamsGCCH', 'TeamsDOD'))
}

function Test-MtCisaTeamsAppControl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DefaultApp', 'GlobalApp', 'PrivateApp')]
        [string]$SettingName,
        [Parameter(Mandatory)]
        [string]$AppType
    )

    $settings = @(Get-MtTeamsUnifiedTenantSettings)
    $setting = $settings | Where-Object { $_.SettingName -eq $SettingName } | Select-Object -First 1
    $policyProperty = switch ($SettingName) {
        'DefaultApp' { 'DefaultCatalogAppsType' }
        'GlobalApp' { 'GlobalCatalogAppsType' }
        'PrivateApp' { 'PrivateCatalogAppsType' }
    }

    $rows = @()
    if ($setting) {
        $value = [string]$setting.SettingValue
        $passed = $value -eq 'None'
        $rows += [pscustomobject]@{
            Policy = 'Org-wide setting'
            Value  = $value
            Pass   = $passed
        }
    } else {
        $policies = @(Get-CsTeamsAppPermissionPolicy -ErrorAction Stop)
        if ($policies.Count -eq 0) {
            throw 'Teams returned no app permission policies.'
        }

        $rows = foreach ($policy in $policies) {
            $type = $policy.PSObject.Properties[$policyProperty]
            if ($null -eq $type -or $type.Value -notin @('AllowedAppList', 'BlockedAppList')) {
                throw "Teams app permission policy '$($policy.Identity)' did not return a supported value for $policyProperty."
            }

            [pscustomobject]@{
                Policy = $policy.Identity
                Value  = $type.Value
                Pass   = $type.Value -eq 'AllowedAppList'
            }
        }
        $passed = @($rows | Where-Object { -not $_.Pass }).Count -eq 0
    }

    $markdown = if ($passed) {
        "Well done. $AppType apps are restricted to the approved set.`n`n"
    } else {
        "$AppType apps are not restricted to the approved set.`n`n"
    }
    $markdown += "| Policy or setting | Value | Result |`n| --- | --- | --- |`n"
    foreach ($row in $rows) {
        $markdown += "| $($row.Policy) | $($row.Value) | $(if ($row.Pass) { 'Pass' } else { 'Fail' }) |`n"
    }
    Add-MtTestResultDetail -Result $markdown.TrimEnd()
    return $passed
}
