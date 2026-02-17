<#
.SYNOPSIS
    7.2.7 (L1) Ensure link sharing is restricted in SharePoint and OneDrive

.DESCRIPTION
    By default, the sharing link experience in SharePoint and OneDrive is set to "Anyone with the link". This means that when users share files or folders, the default option allows anyone with the link to access the content, which can lead to unintentional overexposure of sensitive information. By changing the default sharing link type to "Specific people", users are encouraged to be more deliberate about who they share content with, reducing the risk of unauthorized access and supporting a more secure sharing environment.

.EXAMPLE
    Test-MtSpoDefaultSharingLink

    Returns true if the default sharing link type is set to a restrictive option, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtSpoDefaultSharingLink
#>
function Test-MtSpoDefaultSharingLink {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing default sharing link type in SharePoint Online..."

    $return = $true
    try {
        $DefaultSharingLinkType = Get-SPOTenant | Select-Object -ExpandProperty DefaultSharingLinkType
        if ($DefaultSharingLinkType -eq "Direct" -or $DefaultSharingLinkType -eq "Internal") {
            $testResult = "Well done. Default sharing link type is set to a restrictive option."
        } else {
            $testResult = "Default sharing link type is not set to a restrictive option."
            $return = $false
        }
        Add-MtTestResultDetail -Result $testResult
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}