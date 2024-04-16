<#
.SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Block user consent for risky apps is set to 'true'

.DESCRIPTION

    Defines whether user consent will be blocked when a risky request is detected

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value -eq 'true'

.EXAMPLE
    Test-MtEidscaCP03

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value -eq 'true'
#>

Function Test-MtEidscaCP03 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $tenantValue = $result.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value | Out-String -NoNewLine
    $testResult = $tenantValue -eq 'true'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'true'** for **settings**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
