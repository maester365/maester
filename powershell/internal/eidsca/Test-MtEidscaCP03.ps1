function Test-MtEidscaCP03 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Block user consent for risky apps is set to 'true'

    .DESCRIPTION

    Defines whether user consent will be blocked when a risky request is detected

    Queries settings
    and returns the result of
    graph/settings.values -eq 'true'

    .EXAMPLE
    Test-MtEidscaCP03

    Returns the result of graph.microsoft.com/beta/settings.values -eq 'true'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    
    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $rawValue = $result.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'true'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'true' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'true'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'true'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'High'

    return $tenantValue
}

