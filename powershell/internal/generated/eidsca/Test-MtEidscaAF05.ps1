function Test-MtEidscaAF05 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restricted is set to 'true'

    .DESCRIPTION

    You can work with your Security key provider to determine the AAGuids of their devices for allowing or blocking usage.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the tenant value of
    graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.aaGuids.Count -gt 0 -and $result.keyRestrictions.aaGuids -notcontains $null -and $result.keyRestrictions.aaGuids -notcontains ''

    The native test EIDSCA.AF05 passes when this value -eq 'true'.

    .EXAMPLE
    Test-MtEidscaAF05

    Returns the tenant value of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.aaGuids.Count -gt 0 -and $result.keyRestrictions.aaGuids -notcontains $null -and $result.keyRestrictions.aaGuids -notcontains ''
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    $rawValue = $result.keyRestrictions.aaGuids.Count -gt 0 -and $result.keyRestrictions.aaGuids -notcontains $null -and $result.keyRestrictions.aaGuids -notcontains ''
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'true'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'true' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Low'

    return $tenantValue
}
