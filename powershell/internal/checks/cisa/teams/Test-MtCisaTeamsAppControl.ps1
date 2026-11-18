function Test-MtCisaTeamsAppControl {
    [CmdletBinding()]
    [OutputType([bool])]
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
        if (-not $__MtSession.TeamsCache.ContainsKey('AppPermissionPolicies')) {
            $__MtSession.TeamsCache['AppPermissionPolicies'] = @(Get-CsTeamsAppPermissionPolicy -ErrorAction Stop)
        }
        $policies = @($__MtSession.TeamsCache['AppPermissionPolicies'])
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
