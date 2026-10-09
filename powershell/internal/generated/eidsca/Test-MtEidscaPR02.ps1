function Test-MtEidscaPR02 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory is set to 'True'

    .DESCRIPTION

    If set to Yes, password protection is turned on for Active Directory domain controllers when the appropriate agent is installed.

    Queries settings
    and returns the tenant value of
    graph/settings.values

    The native test EIDSCA.PR02 passes when this value -eq 'True'.

    .EXAMPLE
    Test-MtEidscaPR02

    Returns the tenant value of graph.microsoft.com/beta/settings.values
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $rawValue = $result.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value
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
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'High'

    return $tenantValue
}
