function Test-MtEidscaST09 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content is set to 'True'

    .DESCRIPTION

    Indicating whether or not a guest user can have access to Microsoft 365 groups content. This setting does not require an Azure Active Directory Premium P1 license.

    Queries settings
    and returns the tenant value of
    graph/settings.values

    The native test EIDSCA.ST09 passes when this value -eq 'True'.

    .EXAMPLE
    Test-MtEidscaST09

    Returns the tenant value of graph.microsoft.com/beta/settings.values
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $rawValue = $result.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'True'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'True' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'True'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'True'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'True'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Medium'

    return $tenantValue
}
