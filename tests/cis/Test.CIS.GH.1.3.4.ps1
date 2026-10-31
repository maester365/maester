function Test-MtCisGitHubContributorMfaRequired {
    <#
    .SYNOPSIS
    CIS.GH.1.3.4: Ensure Multi-Factor Authentication (MFA) is required for contributors of new code.

    .DESCRIPTION
    CIS GitHub Benchmark v1.2.0 1.3.4 is Manual. This native test assesses
    the documented configuration audit using required, typed evidence. Organization two-factor enforcement reduces the risk that stolen passwords allow attackers to use outside collaborators' cloud accounts to change code.

    .EXAMPLE
    Test-MtCisGitHubContributorMfaRequired

    Assesses CIS.GH.1.3.4 and reports unavailable required evidence as indeterminate.

    .LINK
    https://maester.dev/docs/tests/CIS.GH.1.3.4
    #>
    [MaesterTest(
        Id = 'CIS.GH.1.3.4',
        Title = 'Ensure Multi-Factor Authentication (MFA) is required for contributors of new code',
        Product = 'github',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'High',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = 'cis-github:1.3.4',
        Service = 'GitHub',
        Lifecycle = 'Stable',
        Author = 'thetechgy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Inspect supplied values before Get-MtSetting's pipeline can unwrap a singleton array.
    $providedModel = if ($__MtSession.MaesterConfig.GlobalSettings) { $__MtSession.MaesterConfig.GlobalSettings.PSObject.Properties['GitHubAccountModel'] } else { $null }
    if ($null -ne $providedModel -and $providedModel.Value -isnot [string]) {
        throw 'GitHubAccountModel must be a string, not an array or another supplied value type.'
    }
    $accountModel = Get-MtSetting -Name GitHubAccountModel -Verbose:$false
    if ($accountModel -isnot [string] -or $accountModel -notin 'Unknown', 'PersonalAccounts', 'EnterpriseManagedUsers') {
        throw 'GitHubAccountModel must be Unknown, PersonalAccounts, or EnterpriseManagedUsers.'
    }

    $apiHost = ([uri]$__MtSession.GitHubConnection.ApiBaseUri).Host
    if ($accountModel -eq 'EnterpriseManagedUsers' -or $apiHost -like 'api.*.ghe.com') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Indeterminate: managed-user MFA is enforced by the external identity provider. GitHub organization 2FA data cannot assess that policy.'
    }
    if ($accountModel -eq 'Unknown') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Indeterminate: set GitHubAccountModel explicitly before assessing the organization 2FA setting.'
    }

    $organization = $__MtSession.GitHubConnection.Organization
    $providedOrganization = if ($__MtSession.MaesterConfig.GlobalSettings) { $__MtSession.MaesterConfig.GlobalSettings.PSObject.Properties['GitHubOrganization'] } else { $null }
    if ($null -ne $providedOrganization -and $providedOrganization.Value -isnot [string]) {
        throw 'GitHubOrganization must be a string, not an array or another supplied value type.'
    }
    $configuredOrganization = Get-MtSetting -Name GitHubOrganization -Verbose:$false
    if ($configuredOrganization -isnot [string]) {
        throw 'GitHubOrganization must be a string.'
    }
    if (-not [string]::IsNullOrWhiteSpace($configuredOrganization) -and $configuredOrganization -ne $organization) {
        throw 'GitHubOrganization does not match the connected organization. Reconnect to the intended target.'
    }

    $evidence = Get-MtGitHubOrganization -ApiVersion '2026-03-10' -IncludeMetadata
    $org = $evidence.Data
    if ($evidence.ContentKind -ne 'Object' -or
        -not $evidence.CollectionIntegrityValid -or $evidence.AccessLimited -or
        $null -eq $org -or $org.GetType() -ne [System.Management.Automation.PSCustomObject] -or
        -not (Test-MtGitHubObjectProperty -InputObject $org -PropertyName 'two_factor_requirement_enabled') -or
        $org.two_factor_requirement_enabled -isnot [bool]) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Indeterminate: the organization response must contain a Boolean two_factor_requirement_enabled value.'
    }

    $result = $org.two_factor_requirement_enabled
    $summary = if ($result) {
        'Well done. The connected organization requires two-factor authentication.'
    } else {
        'Require two-factor authentication in the connected organization after coordinating enrollment and access changes.'
    }
    $target = [System.Net.WebUtility]::HtmlEncode([string]$organization).Replace('|', '&#124;').Replace('`', '&#96;') -replace '[\r\n]', ' '
    if ($target.Length -gt 160) { $target = $target.Substring(0, 160) }
    $resultMarkdown = @"
$summary

CIS.GH.1.3.4 configuration evidence from ``GET /orgs/{org}`` (REST 2026-03-10).

| Evidence | Value |
| --- | --- |
| Organization target | $target |
| ``two_factor_requirement_enabled`` | $result |
| Expected | True |
| Collected UTC | $('{0:o}' -f $evidence.StartedUtc) to $('{0:o}' -f $evidence.CompletedUtc) |

This result concerns the connected organization only; it does not assess all organizations in an enterprise or an external identity provider.
"@
    Add-MtTestResultDetail -Result $resultMarkdown
    return $result
}
