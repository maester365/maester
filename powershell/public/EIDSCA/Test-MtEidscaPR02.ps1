<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory is set to 'True'

.DESCRIPTION

    If set to Yes, password protection is turned on for Active Directory domain controllers when the appropriate agent is installed.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value -eq 'True'

.EXAMPLE
    Test-MtEidscaPR02

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value -eq 'True'
#>

Function Test-MtEidscaPR02 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $tenantValue = $result.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value
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
