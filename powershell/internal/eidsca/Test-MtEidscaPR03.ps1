function Test-MtEidscaPR03 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Enforce custom list is set to 'True'

    .DESCRIPTION

    When enabled, the words in the list below are used in the banned password system to prevent easy-to-guess passwords.

    Queries settings
    and returns the result of
    graph/settings.values -eq 'True'

    .EXAMPLE
    Test-MtEidscaPR03

    Returns the result of graph.microsoft.com/beta/settings.values -eq 'True'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $EntraIDPlan -eq 'Free' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test is for tenants that are licensed for Entra ID P1 or higher. See [Entra ID licensing](https://learn.microsoft.com/entra/fundamentals/licensing)'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $rawValue = $result.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value
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

