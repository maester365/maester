<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if every Git repository with the GitHub Code Security plan enabled also has dependency alerts and
    CodeQL alerts turned on.

    'Dependency alerts' and 'CodeQL alerts' are the Code Security features found under Options for the Code
    Security plan. Enabling the plan without them leaves the repository licensed but unscanned.

    Per feature properties are only returned by api-version 7.2-preview.3 of the Advanced Security org
    enablement API, so this test calls the endpoint directly instead of using Get-ADOPSOrganizationAdvancedSecurity.

    Requires membership of the 'Project Collection Administrators' group or the 'Advanced Security: manage
    settings' permission set to Allow.

    https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops#set-up-code-scanning

.EXAMPLE
    ```
    Test-AzdoOrganizationCodeSecurityScanning
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationCodeSecurityScanning
#>
function Test-AzdoOrganizationCodeSecurityScanning {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationCodeSecurityScanning"

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
        $Message = "This organization uses the bundled GitHub Advanced Security for Azure DevOps SKU, where Code Security is not enabled as a separate plan."
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    $Repositories = @($Enablement.reposEnablementStatus)
    $Enabled = @($Repositories | Where-Object { $_.codeSecurityFeatures.codeSecurityEnabled })

    if ($Enabled.Count -eq 0) {
        $Message = "No repositories in this organization have the GitHub Code Security plan enabled, so the scanning features cannot be assessed. Enrolling repositories in the plan is covered by AZDO.1043."
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
        return $null
    }

    $Incomplete = @($Enabled | Where-Object {
            -not $_.codeSecurityFeatures.codeQLEnabled -or -not $_.codeSecurityFeatures.dependabotEnabled
        })
    $result = $Incomplete.Count -eq 0

    $NotEnrolled = $Repositories.Count - $Enabled.Count

    if ($result) {
        $resultMarkdown = "All $($Enabled.Count) repositories enrolled in the GitHub Code Security plan have dependency alerts and CodeQL alerts turned on.`n`n"
    } else {
        $resultMarkdown = "**Not enabled: dependency alerts or CodeQL alerts on $($Incomplete.Count) of $($Enabled.Count) enrolled repositories.**`n`nThey are licensed for Code Security but are not being scanned.`n`n"
    }

    # State the denominator explicitly. This check only assesses enrolled repositories, so a pass here does
    # not mean the organization is covered.
    $resultMarkdown += "| Scope | Value |`n"
    $resultMarkdown += "| --- | --- |`n"
    $resultMarkdown += "| Repositories enrolled in Code Security | $($Enabled.Count) of $($Repositories.Count) |`n"
    $resultMarkdown += "| Enrolled repositories fully scanned | $($Enabled.Count - $Incomplete.Count) of $($Enabled.Count) |`n"
    $resultMarkdown += "| Repositories not enrolled in Code Security, so no scanning | $NotEnrolled |`n"

    if ($NotEnrolled -gt 0) {
        $resultMarkdown += "`nThis check only assesses the $($Enabled.Count) repositories enrolled in Code Security. The other $NotEnrolled are not enrolled in that plan, so they produce no dependency or code scanning alerts, regardless of whether they are enrolled in Secret Protection. That gap is reported by AZDO.1043.`n"
    }

    if (-not $result) {

        $MissingDependabot = @($Incomplete | Where-Object { -not $_.codeSecurityFeatures.dependabotEnabled })
        $MissingCodeQL = @($Incomplete | Where-Object { -not $_.codeSecurityFeatures.codeQLEnabled })

        $resultMarkdown += "`n| Missing feature | Repositories |`n"
        $resultMarkdown += "| --- | --- |`n"
        $resultMarkdown += "| Dependency alerts | $($MissingDependabot.Count) |`n"
        $resultMarkdown += "| CodeQL alerts | $($MissingCodeQL.Count) |`n"

        $Grouped = Group-AzdoRepositoryByProject -Repository $Incomplete

        $resultMarkdown += "`nEnrolled repositories missing a scanning feature, by project:`n`n"
        $resultMarkdown += "| Project | Repositories missing a feature |`n"
        $resultMarkdown += "| --- | --- |`n"
        $Grouped | ForEach-Object {
            $resultMarkdown += "| $($_.Name) | $($_.Count) |`n"
        }
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
