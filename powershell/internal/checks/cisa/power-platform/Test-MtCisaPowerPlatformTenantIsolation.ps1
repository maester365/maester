function Test-MtCisaPowerPlatformTenantIsolation {
    <#
    .SYNOPSIS
    Evaluates whether Power Platform tenant isolation is enabled.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.3.1: the tenant isolation policy must exist and its isDisabled
    property must be false. A tenant that has never configured the policy fails.

    .EXAMPLE
    Test-MtCisaPowerPlatformTenantIsolation

    Returns true when Power Platform tenant isolation is enabled.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-MtPowerPlatformTenantIsolation
    if ($null -eq $policy) {
        Add-MtTestResultDetail -Result 'The Power Platform tenant isolation policy has never been configured in this tenant, so cross-tenant connections are not restricted.'
        return $false
    }

    $isDisabledProperty = if ($null -eq $policy.properties) { $null } else { $policy.properties.PSObject.Properties['isDisabled'] }
    if ($null -eq $isDisabledProperty -or $isDisabledProperty.Value -isnot [bool]) {
        throw 'The Power Platform tenant isolation policy did not include a Boolean isDisabled value.'
    }

    $testResult = -not $isDisabledProperty.Value
    $enabledText = if ($testResult) { 'On' } else { 'Off' }
    $resultText = if ($testResult) { 'Pass' } else { 'Fail' }
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    $resultMd += "| Restrict cross-tenant connections | $enabledText | $resultText |`n"

    if ($testResult) {
        $message = 'Well done. Power Platform tenant isolation is enabled.'
    }
    else {
        $message = 'Power Platform tenant isolation is disabled, so cross-tenant connections are not restricted.'
    }

    Add-MtTestResultDetail -Result "$message`n`n$resultMd"
    return $testResult
}
