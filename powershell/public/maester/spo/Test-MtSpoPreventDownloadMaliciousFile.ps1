<#
.SYNOPSIS
    Ensure malicious file download prevention is Enabled in SharePoint Online

.DESCRIPTION
    By default, users can't open, move, copy, or share* malicious files that are detected by Safe Attachments for SharePoint, OneDrive, and Microsoft Teams. However, they can delete and download malicious files.

.EXAMPLE
    Test-MtSpoPreventDownloadMaliciousFile

    Returns true if malicious file download prevention is enabled in your SharePoint tenant, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtSpoPreventDownloadMaliciousFile
    #>
function Test-MtSpoPreventDownloadMaliciousFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing malicious file download prevention in SharePoint Online..."

    $return = $true
    try {
        $DisallowInfectedFileDownload  = Get-SPOTenant | Select-Object -ExpandProperty DisallowInfectedFileDownload
        if ($DisallowInfectedFileDownload) {
            $testResult = "Well done. Malicious file download prevention is enabled in your SharePoint tenant."
        } else {
            $testResult = "Malicious file download prevention is not enabled in your SharePoint tenant."
            $return = $false
        }
        Add-MtTestResultDetail -Result $testResult
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}