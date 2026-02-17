<#
.SYNOPSIS
    7.2.11 (L1) Ensure the SharePoint default sharing link permission is set

.DESCRIPTION
    By default, the sharing link permission in SharePoint and OneDrive is set to "Edit". This means that when users share files or folders, the default option allows recipients to edit the content, which can lead to unintentional modifications or deletions of sensitive information. By changing the default sharing link permission to "View", users are encouraged to be more deliberate about granting edit permissions, reducing the risk of unauthorized changes and supporting a more secure sharing environment.

.EXAMPLE
    Test-MtSpoDefaultSharingLinkPermission

    Returns true if the default sharing link permission is set to a restrictive option, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtSpoDefaultSharingLinkPermission
#>
function Test-MtSpoDefaultSharingLinkPermission {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing default sharing link permission in SharePoint Online..."

    $return = $true
    try {
        $DefaultLinkPermission = Get-SPOTenant | Select-Object -ExpandProperty DefaultLinkPermission
        if ($DefaultLinkPermission -eq "View") {
            $testResult = "Well done. Default sharing link permission is set to View."
        } else {
            $testResult = "Default sharing link permission is not set to View."
            $return = $false
        }
        Add-MtTestResultDetail -Result $testResult
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}