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
function Test-MtDeviceRegistrationLocalAdminsRegisteringUser {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Entra Device Registration Policy configuration for Entra Join local admin settings'
    if(-not (Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }
    try {
        $deviceRegistrationPolicy = @(Invoke-MtGraphRequest -RelativeUri 'policies/deviceRegistrationPolicy' -ApiVersion beta)
        $testResult = '```' + "`n"
        $testResult += $deviceRegistrationPolicy.azureADJoin.localAdmins | ConvertTo-Json
        $testResult += "`n"
        $testResult += '```'
        Add-MtTestResultDetail -Result $testResult
        return $deviceRegistrationPolicy.azureADJoin.localAdmins.registeringUsers.'@odata.type' -eq '#microsoft.graph.noDeviceRegistrationMembership'
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}

