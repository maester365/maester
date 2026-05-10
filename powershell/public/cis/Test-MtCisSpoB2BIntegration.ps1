function Test-MtCisSpoB2BIntegration {
    <#
    .SYNOPSIS
        Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled

    .DESCRIPTION
        7.2.2 (L1) Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled
        CIS Microsoft 365 Foundations Benchmark v6.0.1

    .EXAMPLE
        Test-MtCisSpoB2BIntegration

        Returns true if SharePoint and OneDrive integration with Azure AD B2B is enabled

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoB2BIntegration
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing SharePoint Entra B2B integration..."

    $return = $true
    try {
        $B2BIntegration = Get-PnPTenant | Select-Object -ExpandProperty EnableAzureADB2BIntegration
        if ($B2BIntegration) {
            $testResult = "Well done. Your SharePoint tenant is integrated with Microsoft Entra B2B."
        } else {
            $testResult = "Your SharePoint tenant is not integrated with Microsoft Entra B2B."
            $return = $false
        }
        Add-MtTestResultDetail -Result $testResult
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}