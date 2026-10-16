function Test-MtCisPasswordProtectionOnPremises {
    <#
    .SYNOPSIS
        Checks that Microsoft Entra password protection is enabled and enforced for on-premises Active Directory.

    .DESCRIPTION
        Checks that Microsoft Entra password protection is enabled for on-premises Active Directory Domain Services and runs in enforced mode, so that banned passwords are rejected for on-premises password changes too.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.3, L1)

    .EXAMPLE
        Test-MtCisPasswordProtectionOnPremises

        Returns true if on-premises password protection is enabled and set to Enforced.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.3',
        Title = 'Ensure password protection is enabled for on-prem Active Directory',
        Product = 'entra',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1110.003',
        Control = ('cis-m365:5.2.3.3', 'nist-800-53-r5:IA-5(1)'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Checking whether the tenant is cloud-only...'
    $organizationConfig = Invoke-MtGraphRequest -RelativeUri 'organization'
    if ($organizationConfig.onPremisesSyncEnabled -ne $true) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'The tenant is cloud-only (directory synchronization is not enabled), so on-premises Active Directory password protection does not apply.'
        return $null
    }

    Write-Verbose 'Getting the password rule settings...'
    $groupSettings = Invoke-MtGraphRequest -RelativeUri 'groupSettings' -DisableCache
    $passwordRules = @($groupSettings) | Where-Object { $_.templateId -eq '5cf42378-d67d-4f36-ba46-e8b86229381d' }
    $ruleValues = @{}
    foreach ($rule in $passwordRules.values) {
        $ruleValues[$rule.name] = $rule.value
    }

    $enabled = "$($ruleValues['EnableBannedPasswordCheckOnPremises'])"
    $mode = "$($ruleValues['BannedPasswordCheckOnPremisesMode'])"

    $checks = @(
        [pscustomobject]@{ Setting = 'Enable password protection on Windows Server Active Directory'; Value = $(if ($enabled) { $enabled } else { 'Not found' }); Pass = $enabled -eq 'True' }
        [pscustomobject]@{ Setting = 'Mode'; Value = $(if ($mode) { $mode } else { 'Not found' }); Pass = $mode -eq 'Enforce' }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Password protection is enabled and enforced for on-premises Active Directory.'
    $failText = 'Password protection is not enabled and enforced for on-premises Active Directory.'
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