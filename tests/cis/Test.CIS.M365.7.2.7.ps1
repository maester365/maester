function Test-MtCisSpoDefaultSharingLink {
    <#
    .SYNOPSIS
        Ensure link sharing is restricted in SharePoint and OneDrive

    .DESCRIPTION
        7.2.7 (L1) Ensure link sharing is restricted in SharePoint and OneDrive
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.7, L1)

    .EXAMPLE
        Test-MtCisSpoDefaultSharingLink

        Returns true if link sharing is restricted in SharePoint and OneDrive

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoDefaultSharingLink
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.7',
        Title = 'Ensure link sharing is restricted in SharePoint and OneDrive',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1', 'OneDrive', 'SharePoint Online'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing default sharing link type in SharePoint Online..."

    $return = $true
    $spoTenant = Get-MtSpo
    if ($spoTenant.DefaultSharingLinkType -eq "Direct" -or $spoTenant.DefaultSharingLinkType -eq "Internal") {
        $testResult = "Well done. Default sharing link type is set to a restrictive option."
    } else {
        $testResult = "Default sharing link type is not set to a restrictive option."
        $return = $false
    }
    Add-MtTestResultDetail -Result $testResult
    return $return
}
