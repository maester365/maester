<#
.SYNOPSIS
    Ensure your SharePoint tenant is integrated with Microsoft Entra B2B for external sharing.

.DESCRIPTION
    Microsoft Entra B2B integration allows you to manage external sharing in SharePoint Online using Microsoft Entra. With this integration, you can use Microsoft Entra to control access to your SharePoint Online resources, including sites, lists, and libraries. This provides a more secure and streamlined way to manage external sharing in SharePoint Online.
    When Microsoft Entra B2B integration is enabled, you can use Microsoft Entra to create and manage guest users, assign permissions, and monitor access to your SharePoint Online resources. This allows you to have better control over who can access your SharePoint Online resources and what they can do with them.
    The recommended state is EnableAzureADB2BIntegration set to $true.

.EXAMPLE
    Test-MtSpoB2BIntegration

    Returns true if the SharePoint tenant is integrated with Microsoft Entra B2B, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtSpoB2BIntegration
#>
function Test-MtSpoB2BIntegration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing SharePoint Entra B2B integration..."

    $return = $true
    try {
        $B2BIntegration = Get-SPOTenant | Select-Object -ExpandProperty EnableAzureADB2BIntegration
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