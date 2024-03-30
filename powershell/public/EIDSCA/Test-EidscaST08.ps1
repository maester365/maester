<#
.SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner is set to 'false'

.DESCRIPTION

    Indicating whether or not a guest user can be an owner of groups

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value -eq 'false'

.EXAMPLE
    Test-EidscaST08

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value -eq 'false'
#>

Function Test-EidscaST08 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $tenantValue = $result.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value
    $testResult = $tenantValue -eq 'false'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'false'** for **settings**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
