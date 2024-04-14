<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Users can request admin consent to apps they are unable to consent to is set to 'true'

.DESCRIPTION

    Defines if admin consent request feature is enabled or disabled

    Queries policies/adminConsentRequestPolicy
    and returns the result of
     graph/policies/adminConsentRequestPolicy.isEnabled -eq 'true'

.EXAMPLE
    Test-MtEidscaCR01

    Returns the result of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.isEnabled -eq 'true'
#>

Function Test-MtEidscaCR01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $tenantValue = ($result.isEnabled).ToString()
    $testResult = $tenantValue -eq 'true'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'true'** for **policies/adminConsentRequestPolicy**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
