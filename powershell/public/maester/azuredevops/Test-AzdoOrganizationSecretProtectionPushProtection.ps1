<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if every Git repository with the GitHub Secret Protection plan enabled also blocks pushes that
    contain secrets.

    'Push protections' is the optional Secret Protection feature found under Options for the Secret Protection
    plan. 'Secret alerts' is always available and cannot be turned off, so it is not assessed.

    The blockPushes property is only returned when the org enablement API is called with
    includeAllProperties=true, and only api-version 7.2-preview.3 returns the per-plan feature set, so this
    test calls the endpoint directly instead of using Get-ADOPSOrganizationAdvancedSecurity.

    Requires membership of the 'Project Collection Administrators' group or the 'Advanced Security: manage
    settings' permission set to Allow.

    https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#set-up-secret-scanning

.EXAMPLE
    ```
    Test-AzdoOrganizationSecretProtectionPushProtection
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationSecretProtectionPushProtection
#>
function Test-AzdoOrganizationSecretProtectionPushProtection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationSecretProtectionPushProtection"

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $Organization = (Get-ADOPSConnection).Organization
    $Fetch = Get-AzdoAdvancedSecurityEnablement -Organization $Organization -IncludeAllProperties

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
    $Enabled = @($Repositories | Where-Object { $_.secretProtectionFeatures.secretProtectionEnabled })

    if ($Enabled.Count -eq 0) {
        $Message = "No repositories in this organization have the GitHub Secret Protection plan enabled, so push protection cannot be assessed. Enrolling repositories in the plan is covered by AZDO.1040."
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    $Unprotected = @($Enabled | Where-Object { -not $_.secretProtectionFeatures.blockPushes })
    $result = $Unprotected.Count -eq 0

    $NotEnrolled = $Repositories.Count - $Enabled.Count

    if ($result) {
        $resultMarkdown = "All $($Enabled.Count) repositories enrolled in the GitHub Secret Protection plan block pushes that contain secrets.`n`n"
    } else {
        $resultMarkdown = "**Not enabled: push protection on $($Unprotected.Count) of $($Enabled.Count) enrolled repositories.**`n`nSecrets can still be committed to those repositories and will only be reported after the fact.`n`n"
    }

    # State the denominator explicitly. This check only assesses enrolled repositories, so a pass here does
    # not mean the organization is covered.
    $resultMarkdown += "| Scope | Value |`n"
    $resultMarkdown += "| --- | --- |`n"
    $resultMarkdown += "| Repositories enrolled in Secret Protection | $($Enabled.Count) of $($Repositories.Count) |`n"
    $resultMarkdown += "| Enrolled repositories blocking pushes | $($Enabled.Count - $Unprotected.Count) of $($Enabled.Count) |`n"
    $resultMarkdown += "| Repositories not enrolled in Secret Protection, so no push protection | $NotEnrolled |`n"

    if ($NotEnrolled -gt 0) {
        $resultMarkdown += "`nThis check only assesses the $($Enabled.Count) repositories enrolled in Secret Protection. The other $NotEnrolled are not enrolled in that plan, so they are neither scanned for secrets nor protected at push time, regardless of whether they are enrolled in Code Security. That gap is reported by AZDO.1040.`n"
    }

    if (-not $result) {

        $Grouped = Group-AzdoRepositoryByProject -Repository $Unprotected

        $resultMarkdown += "`nEnrolled repositories that do not block pushes, by project:`n`n"
        $resultMarkdown += "| Project | Repositories not blocking pushes |`n"
        $resultMarkdown += "| --- | --- |`n"
        $Grouped | ForEach-Object {
            $resultMarkdown += "| $($_.Name) | $($_.Count) |`n"
        }
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
