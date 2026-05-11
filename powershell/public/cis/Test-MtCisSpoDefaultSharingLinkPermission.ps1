function Test-MtCisSpoDefaultSharingLinkPermission {
    <#
    .SYNOPSIS
        Ensure the SharePoint default sharing link permission is set

    .DESCRIPTION
        7.2.11 (L1) Ensure the SharePoint default sharing link permission is set
        CIS Microsoft 365 Foundations Benchmark v6.0.1

    .EXAMPLE
        Test-MtCisSpoDefaultSharingLinkPermission

        Returns true if the SharePoint default sharing link permission is set to View

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoDefaultSharingLinkPermission
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing default sharing link permission in SharePoint Online..."

    if (!(Test-MtConnection SharePointOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSharePoint
        return $null
    }

    $return = $true
    try {
        $spoTenant = Get-MtSpo
        if ($spoTenant.DefaultLinkPermission -eq "View") {
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