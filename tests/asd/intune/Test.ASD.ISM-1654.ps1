function Test-MtAsdInternetExplorerDisabled {
    <#
    .SYNOPSIS
    Checks that an assigned Intune policy disables Internet Explorer 11 as a standalone browser.

    .DESCRIPTION
    ISM-1654 (Essential Eight, User application hardening, Maturity Level One) asks that Internet Explorer 11
    is disabled or removed.

    The check reads the Intune settings catalog policies for Windows and looks for the Internet Explorer
    setting "Disable Internet Explorer 11 as a standalone browser" set to Enabled in a policy that is assigned.
    Devices where Internet Explorer is removed as a Windows feature satisfy the control without this setting,
    and the ASD Blueprint for Secure Cloud removes it with a platform script. Maester cannot read platform
    scripts, so a tenant that relies on removal fails this check and should turn it off in the configuration.

    .EXAMPLE
    Test-MtAsdInternetExplorerDisabled

    Returns true when an assigned policy disables Internet Explorer 11.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1654
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1654',
        Title = 'Internet Explorer 11 is disabled or removed.',
        Product = 'intune',
        Feature = 'device-configuration',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1189',
        Control = ('essential-eight:ISM-1654', 'nist-800-53-r5:CM-7'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $rows = @(Get-MtIntuneConfigurationPolicySetting | Where-Object { $_.SettingDefinitionId -match '_internetexplorer_disableinternetexplorerapp(_v\d+)?$' })
    $report = foreach ($row in $rows) {
        [pscustomobject]@{ Policy = $row.PolicyName; Enabled = [string]$row.Value -like '*_1'; Assigned = $row.IsAssigned }
    }
    $testResult = @($report | Where-Object { $_.Enabled -and $_.Assigned }).Count -gt 0

    if ($rows.Count -eq 0) {
        $testResultMarkdown = 'No Intune Windows policy configures **Disable Internet Explorer 11 as a standalone browser**. Enable it in a settings catalog policy assigned to your workstations. If you remove the Internet Explorer optional feature instead, as the ASD Blueprint for Secure Cloud does with a platform script, the control is met but Maester cannot see it: turn this test off in `maester-config.json` with `Enabled` set to `false` and the reason.'
    } else {
        $table = "| Policy | Setting | Assigned |`n| --- | --- | --- |`n"
        foreach ($r in $report) { $table += "| $($r.Policy) | $(if ($r.Enabled) { 'Enabled' } else { 'Disabled' }) | $(if ($r.Assigned) { 'Yes' } else { 'No' }) |`n" }
        if ($testResult) {
            $testResultMarkdown = "An Intune policy with an inclusion assignment configures Internet Explorer 11 as disabled as a standalone browser.`n`n$table"
        } else {
            $testResultMarkdown = "The setting is configured, but no assigned policy enables it.`n`n$table"
        }
    }
    $testResultMarkdown += "`n`nThis checks policy configuration and inclusion assignments; it does not verify assignment coverage or exclusions, conflicting policies, or effective settings on devices."
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
