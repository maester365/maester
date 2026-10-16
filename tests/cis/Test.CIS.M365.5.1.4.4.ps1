function Test-MtCisLocalAdminAssignmentLimited {
    <#
    .SYNOPSIS
        Checks that only selected users, or nobody, become local administrator when they join a device to Microsoft Entra ID.

    .DESCRIPTION
        Checks the device registration policy and passes when the users who become local administrators on a device they join to Microsoft Entra ID are limited to selected users or groups, or to none.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.4.4, L1)

    .EXAMPLE
        Test-MtCisLocalAdminAssignmentLimited

        Returns true if registering users are not made local administrators by default.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.4.4
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.4.4',
        Title = 'Ensure local administrator assignment is limited during Entra join',
        Product = 'entra',
        Feature = 'devices',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('cis-m365:5.1.4.4', 'nist-800-53-r5:AC-6'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the device registration policy...'
    $devicePolicy = Invoke-MtGraphRequest -RelativeUri 'policies/deviceRegistrationPolicy' -ApiVersion beta -DisableCache

    $type = "$($devicePolicy.azureADJoin.localAdmins.registeringUsers.'@odata.type')"
    $testResult = $type -eq '#microsoft.graph.enumeratedDeviceRegistrationMembership' -or $type -eq '#microsoft.graph.noDeviceRegistrationMembership'

    $passText = 'Local administrator rights for users who join devices are limited to selected users or groups, or to none.'
    $failText = 'All users who join a device to Microsoft Entra ID become local administrators of it.'

    $display = switch ($type) {
        '#microsoft.graph.allDeviceRegistrationMembership' { 'All users' }
        '#microsoft.graph.enumeratedDeviceRegistrationMembership' { 'Selected users or groups' }
        '#microsoft.graph.noDeviceRegistrationMembership' { 'None' }
        default { 'Not found' }
    }
    $checks = @([pscustomobject]@{ Setting = 'Registering users are local administrators'; Value = $display; Pass = $testResult })
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
