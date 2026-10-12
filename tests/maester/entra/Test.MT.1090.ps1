function Test-MtDeviceRegistrationLocalAdminsGlobalAdmin {
    <#
    .SYNOPSIS
    Tests whether Global Administrators are configured as local administrators on devices during Microsoft Entra join.

    .DESCRIPTION
    Global Administrator role should not be added as local administrator on the device during Microsoft Entra join.

    .EXAMPLE
    Test-MtDeviceRegistrationLocalAdminsGlobalAdmin
    Returns true if Global Administrators are not configured as local administrators on devices during Microsoft Entra join, false if they are, and null if the test could not be completed.

    .LINK
    https://maester.dev/docs/commands/Test-MtDeviceRegistrationLocalAdminsGlobalAdmin
    #>
    [MaesterTest(
        Id = 'MT.1090',
        Title = 'Global Administrator role should not be added as local administrator on the device during Microsoft Entra join',
        Product = 'entra',
        Feature = 'devices',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = 'nist-800-53-r5:AC-6',
        Service = 'Graph',
        Author = 'nicolonsky'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Entra Device Registration Policy configuration for Entra Join local admin settings'

    $deviceRegistrationPolicy = @(Invoke-MtGraphRequest -RelativeUri 'policies/deviceRegistrationPolicy' -ApiVersion beta)
    $testResult = '```' + "`n"
    $testResult += $deviceRegistrationPolicy.azureADJoin.localAdmins | ConvertTo-Json
    $testResult += "`n"
    $testResult += '```'
    Add-MtTestResultDetail -Result $testResult
    return $deviceRegistrationPolicy.azureADJoin.localAdmins.enableGlobalAdmins -eq $false
}
