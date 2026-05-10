function Test-MtCisSpoGuestAccessExpiry {
    <#
    .SYNOPSIS
        Ensure guest access to a site or OneDrive will expire automatically

    .DESCRIPTION
        7.2.9 (L1) Ensure guest access to a site or OneDrive will expire automatically
        CIS Microsoft 365 Foundations Benchmark v6.0.1

    .EXAMPLE
        Test-MtCisSpoGuestAccessExpiry

        Returns true if guest access expiration is enabled and set to 30 days or less

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoGuestAccessExpiry
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing guest access expiration settings in SharePoint Online..."

    $return = $true
    try {
        $spoTenant = Get-SPOTenant
        if ($spoTenant.ExternalUserExpirationRequired -eq $true -and $spoTenant.ExternalUserExpireInDays -gt 0 -and $spoTenant.ExternalUserExpireInDays -le 30) {
            $testResult = "Well done. Guest access expiration is enabled and set to 30 days or less ($($spoTenant.ExternalUserExpireInDays) days)."
        } else {
            $testResult = "Guest access expiration is not enabled or set to more than 30 days."
            $return = $false
        }
        Add-MtTestResultDetail -Result $testResult
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}