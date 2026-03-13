<#
.SYNOPSIS
    7.2.9 (L1) Ensure guest access to a site or OneDrive will expire automatically

.DESCRIPTION
    By default, guest access to a SharePoint site or OneDrive does not expire.
    This means that once a guest user is granted access to a site or OneDrive, they will have indefinite access until manually removed by an administrator. Enabling automatic expiration of guest access helps to ensure that external users do not retain access to sensitive information longer than necessary, reducing the risk of unauthorized access and supporting a more secure sharing environment. The recommended state is to enable guest access expiration and set it to 30 days or less.

.EXAMPLE
    Test-MtSpoGuestAccessExpiry

    Returns true if guest access expiration is enabled and set to 30 days or less, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtSpoGuestAccessExpiry
#>
function Test-MtSpoGuestAccessExpiry {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing guest access expiration settings in SharePoint Online..."

    $return = $true
    try {
        $spoTenant = Get-SPOTenant
        if ($spoTenant.ExternalUserExpirationRequired -eq $true -and $spoTenant.ExternalUserExpireInDays -le 30) {
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