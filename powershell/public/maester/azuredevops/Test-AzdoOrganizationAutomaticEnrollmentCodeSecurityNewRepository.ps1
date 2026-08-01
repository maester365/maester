<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if the GitHub Code Security plan is automatically enabled on newly created Git repositories.

    GitHub Advanced Security for Azure DevOps is sold either as a single bundled plan or as two separate
    plans, GitHub Secret Protection and GitHub Code Security. The per-plan automatic enablement settings are
    only returned by api-version 7.2-preview.3 of the Advanced Security org enablement API. Get-ADOPSOrganizationAdvancedSecurity
    pins api-version 7.2-preview.1, which only returns the bundled 'enableOnCreate' value, so this test calls
    the endpoint directly.

    Organizations still on the bundled SKU are skipped, since the bundled equivalent is covered by AZDO.1026.

    Requires membership of the 'Project Collection Administrators' group or the 'Advanced Security: manage
    settings' permission set to Allow.

    https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#organization-level-onboarding

.EXAMPLE
    ```
    Test-AzdoOrganizationAutomaticEnrollmentCodeSecurityNewRepository
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationAutomaticEnrollmentCodeSecurityNewRepository
#>
function Test-AzdoOrganizationAutomaticEnrollmentCodeSecurityNewRepository {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationAutomaticEnrollmentCodeSecurityNewRepository"

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $Organization = (Get-ADOPSConnection).Organization
    $Fetch = Get-AzdoAdvancedSecurityEnablement -Organization $Organization

    if ($null -ne $Fetch.RequestError) {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $Fetch.RequestError
        return $null
    }

    $Enablement = $Fetch.Enablement

    if ($Enablement.isBundledSKU) {
        $Message = "This organization uses the bundled GitHub Advanced Security for Azure DevOps SKU, where Code Security is not enabled as a separate plan. Automatic enablement for the bundled SKU is covered by AZDO.1026."
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    $OnCreate = $Enablement.enablementOnCreateSettings

    if ($null -eq $OnCreate) {
        $Message = "The Advanced Security org enablement API did not return any automatic enablement settings. The signed in identity may lack the 'Advanced Security: manage settings' permission. Please see [Configure GitHub Advanced Security features](https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#organization-level-onboarding)"
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    $result = [bool]$OnCreate.enableCodeSecurityOnCreate

    if ($result) {
        $resultMarkdown = "Newly created Git repositories will automatically have the GitHub Code Security plan enabled.`n`n"
    } else {
        $resultMarkdown = "**Not enabled: Code Security on new repositories.**`n`nEvery Git repository created from now on starts with no dependency scanning and no code scanning, and has to be onboarded by hand.`n`n"
    }

    $resultMarkdown += "| Setting | Value |`n"
    $resultMarkdown += "| --- | --- |`n"
    $resultMarkdown += "| Code Security enabled on new repositories | $(if ($result) { 'True' } else { '**False**' }) |`n"
    $resultMarkdown += "`nThis setting only affects repositories created from this point on. Coverage of the repositories that already exist is assessed separately by AZDO.1043.`n"

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
