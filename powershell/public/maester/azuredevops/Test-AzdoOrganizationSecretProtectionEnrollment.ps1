<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if any existing Git repository in the organization is enrolled in the GitHub Secret Protection plan.

    Automatic enablement only applies to newly created repositories, so an organization can have the
    auto enablement setting turned on while every existing repository remains unprotected. This test assesses
    actual coverage of the existing repositories, which AZDO.1039 deliberately does not.

    Per plan enrolment is only returned by api-version 7.2-preview.3 of the Advanced Security org enablement
    API, so this test calls the endpoint directly instead of using Get-ADOPSOrganizationAdvancedSecurity.

    Requires membership of the 'Project Collection Administrators' group or the 'Advanced Security: manage
    settings' permission set to Allow.

    https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#organization-level-onboarding

.EXAMPLE
    ```
    Test-AzdoOrganizationSecretProtectionEnrollment
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationSecretProtectionEnrollment
#>
function Test-AzdoOrganizationSecretProtectionEnrollment {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationSecretProtectionEnrollment"

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
        $Message = "This organization uses the bundled GitHub Advanced Security for Azure DevOps SKU, where Secret Protection is not enabled as a separate plan."
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    $Repositories = @($Enablement.reposEnablementStatus)

    if ($Repositories.Count -eq 0) {
        $Message = "The Advanced Security org enablement API did not return any repositories, so Secret Protection coverage cannot be assessed."
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    $Enrolled = @($Repositories | Where-Object { $_.secretProtectionFeatures.secretProtectionEnabled })
    $Unenrolled = @($Repositories | Where-Object { -not $_.secretProtectionFeatures.secretProtectionEnabled })

    $result = $Unenrolled.Count -eq 0

    if ($result) {
        $resultMarkdown = "All $($Repositories.Count) Git repositories in your organization are enrolled in the GitHub Secret Protection plan.`n`n"
    } elseif ($Enrolled.Count -eq 0) {
        $resultMarkdown = "**Not enrolled: all $($Repositories.Count) repositories.**`n`nNo repository in your organization is enrolled in the GitHub Secret Protection plan, so none is scanned for secrets and no push is blocked for containing one.`n`n"
    } else {
        $resultMarkdown = "**Not enrolled: $($Unenrolled.Count) of $($Repositories.Count) repositories.**`n`n$($Enrolled.Count) are enrolled in the GitHub Secret Protection plan; the remaining $($Unenrolled.Count) are not scanned for secrets.`n`n"
    }

    $resultMarkdown += "| Coverage | Value |`n"
    $resultMarkdown += "| --- | --- |`n"
    $resultMarkdown += "| Repositories enrolled | $($Enrolled.Count) of $($Repositories.Count) |`n"
    $resultMarkdown += "| Repositories not enrolled | $(if ($Unenrolled.Count -gt 0) { "**$($Unenrolled.Count)**" } else { '0' }) |`n"

    if ($Unenrolled.Count -gt 0) {


        $Grouped = Group-AzdoRepositoryByProject -Repository $Unenrolled

        $resultMarkdown += "`nRepositories not enrolled in Secret Protection, by project:`n`n"
        $resultMarkdown += "| Project | Repositories not enrolled |`n"
        $resultMarkdown += "| --- | --- |`n"
        $Grouped | ForEach-Object {
            $resultMarkdown += "| $($_.Name) | $($_.Count) |`n"
        }
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
