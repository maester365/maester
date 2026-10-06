function Test-MtCisSpoGuestAccessExpiry {
    <#
    .SYNOPSIS
        Ensure guest access to a site or OneDrive will expire automatically

    .DESCRIPTION
        7.2.9 (L1) Ensure guest access to a site or OneDrive will expire automatically
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.9, L1)

    .EXAMPLE
        Test-MtCisSpoGuestAccessExpiry

        Returns true if guest access expiration is enabled and set to 30 days

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoGuestAccessExpiry
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.9',
        Title = 'Ensure guest access to a site or OneDrive will expire automatically',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1', 'OneDrive', 'SharePoint Online'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing guest access expiration settings in SharePoint Online..."

    if (!(Test-MtConnection SharePointOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSharePoint
        return $null
    }

    $return = $true
    $spoTenant = Get-MtSpo
    if ($spoTenant.ExternalUserExpirationRequired -eq $true -and $spoTenant.ExternalUserExpireInDays -eq 30) {
        $testResult = "Well done. Guest access expiration is enabled and set to 30 days."
    } else {
        $testResult = "Guest access expiration is not enabled or not set to 30 days ($($spoTenant.ExternalUserExpireInDays) days)."
        $return = $false
    }
    Add-MtTestResultDetail -Result $testResult
    return $return
}
