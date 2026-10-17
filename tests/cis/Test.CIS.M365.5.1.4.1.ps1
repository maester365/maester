function Test-MtCisEntraJoinRestricted {
    <#
    .SYNOPSIS
        Checks that only selected users or groups, or nobody, can join devices to Microsoft Entra ID.

    .DESCRIPTION
        Checks the device registration policy and passes when the users that can join devices to Microsoft Entra ID are limited to selected users or groups, or to none.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.4.1, L2)

    .EXAMPLE
        Test-MtCisEntraJoinRestricted

        Returns true if joining devices to Microsoft Entra ID is limited to selected users or nobody.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.4.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.4.1',
        Title = 'Ensure the ability to join devices to Entra is restricted',
        Product = 'entra',
        Feature = 'devices',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1098.005',
        Control = ('cis-m365:5.1.4.1', 'nist-800-53-r5:IA-3'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the device registration policy...'
    $devicePolicy = Invoke-MtGraphRequest -RelativeUri 'policies/deviceRegistrationPolicy' -ApiVersion beta

    $type = "$($devicePolicy.azureADJoin.allowedToJoin.'@odata.type')"
    $testResult = $type -eq '#microsoft.graph.enumeratedDeviceRegistrationMembership' -or $type -eq '#microsoft.graph.noDeviceRegistrationMembership'

    $passText = 'Joining devices to Microsoft Entra ID is limited to selected users or groups, or to none.'
    $failText = 'All users can join devices to Microsoft Entra ID.'

    $display = switch ($type) {
        '#microsoft.graph.allDeviceRegistrationMembership' { 'All users' }
        '#microsoft.graph.enumeratedDeviceRegistrationMembership' { 'Selected users or groups' }
        '#microsoft.graph.noDeviceRegistrationMembership' { 'None' }
        default { 'Not found' }
    }
    $checks = @([pscustomobject]@{ Setting = 'Users may join devices to Microsoft Entra ID'; Value = $display; Pass = $testResult })
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
