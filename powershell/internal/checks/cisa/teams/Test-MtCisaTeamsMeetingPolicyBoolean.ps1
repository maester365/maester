function Test-MtCisaTeamsMeetingPolicyBoolean {
    [CmdletBinding()]
    [OutputType([bool])]
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
