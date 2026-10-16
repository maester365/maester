function Test-MtCisLapsEnabled {
    <#
    .SYNOPSIS
        Checks that Windows Local Administrator Password Solution is enabled for Microsoft Entra.

    .DESCRIPTION
        Checks the device registration policy and passes when Windows Local Administrator Password Solution (LAPS) is enabled for the tenant, so that devices can store a unique local administrator password in Microsoft Entra ID.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.4.5, L1)

    .EXAMPLE
        Test-MtCisLapsEnabled

        Returns true if LAPS is enabled in the device settings.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.4.5
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.4.5',
        Title = 'Ensure Local Administrator Password Solution is enabled',
        Product = 'entra',
        Feature = 'devices',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.003',
        Control = ('cis-m365:5.1.4.5', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the device registration policy...'
    $devicePolicy = Invoke-MtGraphRequest -RelativeUri 'policies/deviceRegistrationPolicy' -ApiVersion beta -DisableCache

    $value = $devicePolicy.localAdminPassword.isEnabled
    $testResult = $value -eq $true

    $passText = 'Windows Local Administrator Password Solution is enabled.'
    $failText = 'Windows Local Administrator Password Solution is not enabled.'

    $checks = @([pscustomobject]@{ Setting = 'Enable Microsoft Entra Local Administrator Password Solution (LAPS)'; Value = $(if ($null -eq $value) { 'Not found' } else { $value }); Pass = $testResult })
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
