function Test-MtCisSpoPreventDownloadMaliciousFile {
    <#
    .SYNOPSIS
        Ensure Office 365 SharePoint infected files are disallowed for download

    .DESCRIPTION
        7.3.1 (L2) Ensure Office 365 SharePoint infected files are disallowed for download
        CIS Microsoft 365 Foundations Benchmark v6.0.1

    .EXAMPLE
        Test-MtCisSpoPreventDownloadMaliciousFile

        Returns true if Office 365 SharePoint infected files are disallowed for download

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoPreventDownloadMaliciousFile
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing malicious file download prevention in SharePoint Online..."

    $return = $true
    try {
        $DisallowInfectedFileDownload = Get-SPOTenant | Select-Object -ExpandProperty DisallowInfectedFileDownload
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