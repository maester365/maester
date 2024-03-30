<#
.SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content is set to 'True'

.DESCRIPTION

    Indicating whether or not a guest user can have access to Microsoft 365 groups content. This setting does not require an Azure Active Directory Premium P1 license.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value -eq 'True'

.EXAMPLE
    Test-MtEidscaST09

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value -eq 'True'
#>

Function Test-MtEidscaST09 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $tenantValue = $result.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value
    $testResult = $tenantValue -eq 'True'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'True'** for **settings**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'True'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
