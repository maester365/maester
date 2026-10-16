function Test-MtCisPasswordHashSyncEnabled {
    <#
    .SYNOPSIS
        Checks that password hash synchronization is enabled when directory synchronization is configured.

    .DESCRIPTION
        Checks the on-premises directory synchronization settings and passes when password hash synchronization is enabled, or when no directory synchronization is configured. Tenants that only synchronise with a different method can treat a failure as an exception.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.8.1, L1)

    .EXAMPLE
        Test-MtCisPasswordHashSyncEnabled

        Returns true if password hash synchronization is enabled or directory synchronization is not used.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.8.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.8.1',
        Title = 'Ensure that password hash sync is enabled for hybrid deployments',
        Product = 'entra',
        Feature = 'hybrid-identity',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:5.1.8.1', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the on-premises synchronization settings...'
    $sync = Invoke-MtGraphRequest -RelativeUri 'directory/onPremisesSynchronization' -DisableCache
    $syncConfigs = @($sync) | Where-Object { $_ }
    $value = $syncConfigs[0].features.passwordSyncEnabled
    $testResult = $syncConfigs.Count -eq 0 -or $value -eq $true

    $passText = if ($syncConfigs.Count -eq 0) { 'Directory synchronization is not configured, so password hash synchronization does not apply.' } else { 'Password hash synchronization is enabled.' }
    $failText = 'Password hash synchronization is not enabled.'

    $display = if ($syncConfigs.Count -eq 0) { 'Directory synchronization not configured' } elseif ($null -eq $value) { 'Not found' } else { $value }
    $checks = @([pscustomobject]@{ Setting = 'passwordSyncEnabled'; Value = $display; Pass = $testResult })
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
