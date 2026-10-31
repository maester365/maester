function Test-MtAsdOfficeMacroAntivirusScanning {
    <#
    .SYNOPSIS
    Checks that an assigned Intune policy enables antivirus scanning of Microsoft Office macros at runtime.

    .DESCRIPTION
    ISM-1672 (Essential Eight, Restrict Microsoft Office macros, Maturity Level One) asks that Microsoft Office
    macro antivirus scanning is enabled.

    The check reads the Intune settings catalog policies for Windows and looks for the Office setting
    "Macro Runtime Scan Scope" set to Enabled with the scope "Enable for all documents", in a policy that is
    assigned. ASD's guide to restricting Microsoft Office macros and the ASD Blueprint for Secure Cloud both set
    all documents, and the assessment process guide calls it the ideal value. "Enable for low trust documents"
    scans only files with the Mark of the Web, whose macros ISM-1488 already blocks, so it does not count. The scan hands macro behaviour to the
    Antimalware Scan Interface (AMSI), where Microsoft Defender Antivirus or another registered antivirus
    inspects it.

    .EXAMPLE
    Test-MtAsdOfficeMacroAntivirusScanning

    Returns true when an assigned policy enables macro runtime scanning for all documents.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1672
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1672',
        Title = 'Microsoft Office macro antivirus scanning is enabled.',
        Product = 'intune',
        Feature = 'device-configuration',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1204.002',
        Control = ('essential-eight:ISM-1672', 'nist-800-53-r5:SI-3'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $rows = @(Get-MtIntuneConfigurationPolicySetting | Where-Object { $_.SettingDefinitionId -like '*_l_macroruntimescanscope*' })
    $scopes = @{ '0' = 'Disabled for all documents'; '1' = 'Enabled for low trust documents'; '2' = 'Enabled for all documents' }

    $report = foreach ($setting in @($rows | Where-Object { $_.SettingDefinitionId -like '*_l_macroruntimescanscope' })) {
        $enabled = [string]$setting.Value -like '*_1'
        $scopeRow = $rows | Where-Object { $_.PolicyId -eq $setting.PolicyId -and $_.ParentDefinitionId -eq $setting.SettingDefinitionId } | Select-Object -First 1
        $scopeValue = if ($scopeRow) { ([string]$scopeRow.Value) -replace '^.*_(\d)$', '$1' } else { $null }
        [pscustomobject]@{
            Policy   = $setting.PolicyName
            Assigned = $setting.IsAssigned
            Enabled  = $enabled
            Scope    = if ($enabled -and $scopes.ContainsKey([string]$scopeValue)) { $scopes[[string]$scopeValue] } elseif ($enabled) { 'Unknown' } else { 'Not configured' }
            Scans    = $enabled -and $scopeValue -eq '2'
        }
    }
    $effective = @($report | Where-Object { $_.Assigned -and $_.Scans })
    $testResult = $effective.Count -gt 0

    if (@($report).Count -eq 0) {
        $testResultMarkdown = 'No Intune Windows policy configures the Office setting **Macro Runtime Scan Scope**. Enable it for all documents in a settings catalog policy that is assigned to your users.'
    } else {
        $table = "| Policy | Macro runtime scan | Assigned |`n| --- | --- | --- |`n"
        foreach ($r in $report) { $table += "| $($r.Policy) | $($r.Scope) | $(if ($r.Assigned) { 'Yes' } else { 'No' }) |`n" }
        if ($testResult) {
            $testResultMarkdown = "An Intune policy with an inclusion assignment configures antivirus scanning of Office macros at runtime for all documents.`n`n$table"
        } else {
            $testResultMarkdown = "The Office setting **Macro Runtime Scan Scope** is configured, but no assigned policy enables it for all documents.`n`n$table"
        }
    }
    $testResultMarkdown += "`n`nThis checks policy configuration and inclusion assignments; it does not verify assignment coverage or exclusions, conflicting policies, or effective settings on devices."
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
