function Test-MtCisMaximumDevicesPerUser {
    <#
    .SYNOPSIS
        Checks that the maximum number of devices per user is not above the allowed maximum.

    .DESCRIPTION
        Checks the device registration policy and passes when the maximum number of devices that a user can have in Microsoft Entra ID is set and does not exceed the allowed maximum.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.4.2, L1)

    .EXAMPLE
        Test-MtCisMaximumDevicesPerUser

        Returns true if the per-user device limit is 10 or lower.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.4.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.4.2',
        Title = 'Ensure the maximum number of devices per user is limited',
        Product = 'entra',
        Feature = 'devices',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1098.005',
        Control = ('cis-m365:5.1.4.2', 'nist-800-53-r5:CM-8'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum number of devices that a user can have.
        [ValidateRange(1, 100)]
        [int] $MaximumDevicesPerUser = 10
    )

    Write-Verbose 'Getting the device registration policy...'
    $devicePolicy = Invoke-MtGraphRequest -RelativeUri 'policies/deviceRegistrationPolicy' -ApiVersion beta -DisableCache

    $quota = $devicePolicy.userDeviceQuota
    $testResult = $null -ne $quota -and [int]$quota -le $MaximumDevicesPerUser

    $passText = "The maximum number of devices per user is $quota."
    $failText = "The maximum number of devices per user is $quota. It should be $MaximumDevicesPerUser or fewer."

    $resultMd = "| Setting | Value | Maximum | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    $resultMd += "| Maximum number of devices per user | $(if ($null -eq $quota) { 'Not found' } else { $quota }) | $MaximumDevicesPerUser | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
