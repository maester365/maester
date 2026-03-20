<#
.SYNOPSIS
    Checks if file and folder default sharing scope is set to Specific people

.DESCRIPTION
    File and folder default sharing scope SHALL be set to Specific people (only the people the user specifies).

    This test checks both the new property (CoreDefaultShareLinkScope) and the legacy property
    (DefaultSharingLinkType) to account for tenants in different stages of the Microsoft property
    name transition.

.EXAMPLE
    Test-MtCisaSpoDefaultSharingScope

    Returns true if default sharing scope is Specific people

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoDefaultSharingScope
#>
function Test-MtCisaSpoDefaultSharingScope {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    if ($null -eq $spoTenant) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "SharePoint Online PowerShell module is not connected. Run Connect-SPOService first."
        return $null
    }

    # Check the new property first, fall back to legacy
    $newProperty = $spoTenant.CoreDefaultShareLinkScope
    $legacyProperty = $spoTenant.DefaultSharingLinkType

    # New property: SpecificPeople = pass
    # Legacy property: Direct = pass (maps to SpecificPeople)
    $testResult = $false
    $evaluatedProperty = ""
    $evaluatedValue = ""

    if ($null -ne $newProperty -and $newProperty -ne '') {
        $evaluatedProperty = "CoreDefaultShareLinkScope"
        $evaluatedValue = $newProperty
        $testResult = $newProperty -eq 'SpecificPeople'
    } elseif ($null -ne $legacyProperty -and $legacyProperty -ne '') {
        $evaluatedProperty = "DefaultSharingLinkType"
        $evaluatedValue = $legacyProperty
        $testResult = $legacyProperty -eq 'Direct'
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Default sharing scope is set to **Specific people** ($evaluatedProperty = $evaluatedValue).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Default sharing scope is set to **$evaluatedValue**. It should be set to **Specific people**.`n`n%TestResult%"
    }

    $result = "| Setting | Value |`n"
    $result += "| --- | --- |`n"
    if ($null -ne $newProperty -and $newProperty -ne '') {
        $result += "| CoreDefaultShareLinkScope | $newProperty |`n"
    }
    if ($null -ne $legacyProperty -and $legacyProperty -ne '') {
        $result += "| DefaultSharingLinkType | $legacyProperty |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
