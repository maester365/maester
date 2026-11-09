function Test-MtAsdOfficeMacrosFromInternetBlocked {
    <#
    .SYNOPSIS
    Checks that an assigned Intune policy blocks Microsoft Office macros in files from the internet for Word, Excel and PowerPoint.

    .DESCRIPTION
    ISM-1488 (Essential Eight, Restrict Microsoft Office macros, Maturity Level One) asks that Microsoft Office
    macros in files originating from the internet are blocked.

    The check reads the Intune settings catalog policies for Windows and looks for the Office setting
    "Block macros from running in Office files from the Internet" set to Enabled for each of Word, Excel and
    PowerPoint, in a policy that is assigned. Access, Visio, Project and Publisher are reported when found but
    are not required.

    Policies deployed as Group Policy or through the Office cloud policy service are not read.

    .EXAMPLE
    Test-MtAsdOfficeMacrosFromInternetBlocked

    Returns true when Word, Excel and PowerPoint each have the setting enabled in an assigned policy.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1488
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1488',
        Title = 'Microsoft Office macros in files originating from the internet are blocked.',
        Product = 'intune',
        Feature = 'device-configuration',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1204.002', 'T1566.001'),
        Control = ('essential-eight:ISM-1488', 'nist-800-53-r5:CM-7'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # The Office applications and the start of their setting definition IDs in the settings catalog.
    $applications = [ordered]@{
        Word       = 'user_vendor_msft_policy_config_word16v'
        Excel      = 'user_vendor_msft_policy_config_excel16v'
        PowerPoint = 'user_vendor_msft_policy_config_ppt16v'
        Access     = 'user_vendor_msft_policy_config_access16v'
        Visio      = 'user_vendor_msft_policy_config_visio16v'
        Project    = 'user_vendor_msft_policy_config_proj16v'
        Publisher  = 'user_vendor_msft_policy_config_pub16v'
    }
    $required = @('Word', 'Excel', 'PowerPoint')

    $rows = @(Get-MtIntuneConfigurationPolicySetting | Where-Object { $_.SettingDefinitionId -like '*_l_blockmacroexecutionfrominternet' })

    $report = foreach ($application in $applications.Keys) {
        $settings = @($rows | Where-Object { $_.SettingDefinitionId.StartsWith($applications[$application], [System.StringComparison]::OrdinalIgnoreCase) })
        $blocking = @($settings | Where-Object { $_.IsAssigned -and [string]$_.Value -like '*_1' })
        [pscustomobject]@{
            Application = $application
            Required    = $application -in $required
            Blocked     = $blocking.Count -gt 0
            Policies    = @($blocking.PolicyName | Sort-Object -Unique) -join ', '
            Configured  = $settings.Count -gt 0
        }
    }
    $missing = @($report | Where-Object { $_.Required -and -not $_.Blocked })
    $testResult = $missing.Count -eq 0

    $table = "| Application | Blocked from the internet | Assigned policy |`n| --- | --- | --- |`n"
    foreach ($r in $report) {
        if (-not $r.Configured -and -not $r.Required) { continue }
        $state = if ($r.Blocked) { 'Yes' } elseif ($r.Configured) { 'Configured but not enabled or not assigned' } else { 'Not configured' }
        $table += "| $($r.Application) | $state | $($r.Policies) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Intune policies with inclusion assignments configure Word, Excel and PowerPoint to block macros in files from the internet.`n`n$table"
    } else {
        $testResultMarkdown = "Macros in files from the internet are not blocked for $(@($missing.Application) -join ', ') by an assigned Intune policy.`n`n$table"
    }
    $testResultMarkdown += "`n`nThis checks policy configuration and inclusion assignments; it does not verify assignment coverage or exclusions, conflicting policies, or effective settings on devices."
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
