function Test-MtEidscaST08 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner is set to 'false'

    .DESCRIPTION

    Indicating whether or not a guest user can be an owner of groups, manage

    Queries settings
    and returns the tenant value of
    graph/settings.values

    The native test EIDSCA.ST08 passes when this value -eq 'false'.

    .EXAMPLE
    Test-MtEidscaST08

    Returns the tenant value of graph.microsoft.com/beta/settings.values
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $rawValue = $result.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'false'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'false' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'false'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'false'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Medium'

    return $tenantValue
}
