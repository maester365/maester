<#
.SYNOPSIS
    Checks if group owners can consent to apps

.DESCRIPTION

    Group owners SHALL NOT be allowed to consent to applications.

.EXAMPLE
    Test-MtCisaAppGroupOwnerConsent

    Returns true if disabled
#>

Function Test-MtCisaAppGroupOwnerConsent {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    #May need update to https://learn.microsoft.com/en-us/graph/api/resources/teamsappsettings?view=graph-rest-1.0
    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $testResult = ($result.values | Where-Object {`
        $_.name -eq "EnableGroupSpecificConsent" } | `
        Select-Object -ExpandProperty value) -eq $false

    if ($testResult) {
        $testResultMarkdown = "Well done. Groups owners cannot consent to applications."
    } else {
        $testResultMarkdown = "Your tenant allows group owners to consent to applications."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}