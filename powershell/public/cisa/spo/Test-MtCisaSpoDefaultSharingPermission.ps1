<#
.SYNOPSIS
    Checks if file and folder default sharing permissions are set to view only

.DESCRIPTION
    File and folder default sharing permissions SHALL be set to view only.

    This test checks both the new property (CoreDefaultShareLinkRole) and the legacy property
    (DefaultLinkPermission) to account for tenants in different stages of the Microsoft property
    name transition.

.EXAMPLE
    Test-MtCisaSpoDefaultSharingPermission

    Returns true if default sharing permissions are view only

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoDefaultSharingPermission
#>
function Test-MtCisaSpoDefaultSharingPermission {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    if ($null -eq $spoTenant) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "SharePoint Online PowerShell module is not connected. Run Connect-SPOService first."
        return $null
    }

    # Check the new property first, fall back to legacy
    $newProperty = $spoTenant.CoreDefaultShareLinkRole
    $legacyProperty = $spoTenant.DefaultLinkPermission

    # New property: View = pass
    # Legacy property: View = pass
    $testResult = $false
    $evaluatedProperty = ""
    $evaluatedValue = ""

    if ($null -ne $newProperty -and $newProperty -ne '') {
        $evaluatedProperty = "CoreDefaultShareLinkRole"
        $evaluatedValue = $newProperty
        $testResult = $newProperty -eq 'View'
    } elseif ($null -ne $legacyProperty -and $legacyProperty -ne '') {
        $evaluatedProperty = "DefaultLinkPermission"
        $evaluatedValue = $legacyProperty
        $testResult = $legacyProperty -eq 'View'
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Default sharing permissions are set to **View** ($evaluatedProperty = $evaluatedValue).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Default sharing permissions are set to **$evaluatedValue**. They should be set to **View**.`n`n%TestResult%"
    }

    $result = "| Setting | Value |`n"
    $result += "| --- | --- |`n"
    if ($null -ne $newProperty -and $newProperty -ne '') {
        $result += "| CoreDefaultShareLinkRole | $newProperty |`n"
    }
    if ($null -ne $legacyProperty -and $legacyProperty -ne '') {
        $result += "| DefaultLinkPermission | $legacyProperty |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
