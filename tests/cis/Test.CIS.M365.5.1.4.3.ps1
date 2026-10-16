function Test-MtCisGlobalAdminNotLocalAdmin {
    <#
    .SYNOPSIS
        Checks that the Global Administrator role is not added as local administrator on Microsoft Entra joined devices.

    .DESCRIPTION
        Checks the device registration policy and passes when the Global Administrator role is not automatically added to the local administrators group of devices that are joined to Microsoft Entra ID.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.4.3, L1)

    .EXAMPLE
        Test-MtCisGlobalAdminNotLocalAdmin

        Returns true if Global Administrators are not local administrators on joined devices.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.4.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.4.3',
        Title = 'Ensure the GA role is not added as a local administrator during Entra join',
        Product = 'entra',
        Feature = 'devices',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:5.1.4.3', 'nist-800-53-r5:AC-6'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the device registration policy...'
    $devicePolicy = Invoke-MtGraphRequest -RelativeUri 'policies/deviceRegistrationPolicy' -ApiVersion beta -DisableCache

    $value = $devicePolicy.azureADJoin.localAdmins.enableGlobalAdmins
    $testResult = $value -eq $false

    $passText = 'Global Administrators are not added as local administrators on Microsoft Entra joined devices.'
    $failText = 'Global Administrators are added as local administrators on Microsoft Entra joined devices.'

    $checks = @([pscustomobject]@{ Setting = 'Global administrators are local administrators'; Value = $(if ($null -eq $value) { 'Not found' } else { $value }); Pass = $testResult })
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
