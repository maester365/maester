<#
.SYNOPSIS
    Checks if Authentication Method - SMS - Use for sign-in is set to 'false'

.DESCRIPTION

    Determines if users can use this authentication method to sign in to Microsoft Entra ID. true if users can use this method for primary authentication, otherwise false.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms').includeTargets.isUsableForSignIn -eq 'false'

.EXAMPLE
    Test-MtEidscaAS04

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms').includeTargets.isUsableForSignIn -eq 'false'
#>

function Test-MtEidscaAS04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $EnabledAuthMethods -notcontains 'Sms' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of Sms is not enabled.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')" -ApiVersion beta

    $includeTargets = @($result.includeTargets)
    $tenantValueNotSet = ($includeTargets.Count -eq 0) -and 'false' -notlike '*$null*'

    if (-not $tenantValueNotSet) {
        $failingTargets = @($includeTargets | Where-Object { [string]$_.isUsableForSignIn -ne 'false' })
        $testResult = $failingTargets.Count -eq 0
        $tenantValue = if ($testResult) { 'false' } else { 'true' }
    } else {
        $testResult = $false
        $tenantValue = $null
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'false'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'false'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $directoryObjects = Get-MtDirectoryObjects -ObjectId $failingTargets.id
        $failingDetails = ($failingTargets | ForEach-Object {
            $target = $PSItem
            $displayName = ($directoryObjects | Where-Object { $_.id -eq $target.id }).displayName
            if (-not $displayName) { $displayName = $target.id }
            "- Target **$displayName**: isUsableForSignIn = **$($target.isUsableForSignIn)**"
        }) -join "`n"
        $testResultMarkdown = "Your tenant has **$($failingTargets.Count)** target(s) with **isUsableForSignIn** not set to **false** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')**:`n`n$failingDetails`n`nThe recommended value is **'false'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'High'

    return $tenantValue
}
