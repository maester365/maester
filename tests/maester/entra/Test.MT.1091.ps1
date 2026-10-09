function Test-MtDeviceRegistrationLocalAdminsRegisteringUser {
    <#
    .SYNOPSIS
    Tests whether registering users are configured as local administrators on devices during Microsoft Entra join.

    .DESCRIPTION
    Registering users should not be added as local administrators on the device during Microsoft Entra join.

    .EXAMPLE
    Test-MtDeviceRegistrationLocalAdminsRegisteringUser

    Returns true if registering users are not configured as local administrators on devices during Microsoft Entra join, false if they are, and null if the test could not be completed.

    .LINK
    https://maester.dev/docs/commands/Test-MtDeviceRegistrationLocalAdminsRegisteringUser
    #>
    [MaesterTest(
        Id = 'MT.1091',
        Title = 'Registering user should not be added as local administrator on the device during Microsoft Entra join',
        Severity = 'Medium',
        Category = 'Maester/Entra',
        Tag = ('Device', 'Entra', 'Maester'),
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
    return $deviceRegistrationPolicy.azureADJoin.localAdmins.registeringUsers.'@odata.type' -eq '#microsoft.graph.noDeviceRegistrationMembership'
}
