function Test-MtCaBaselineScopesEnforcement {
    <#
    .SYNOPSIS
    Checks if Conditional Access baseline scopes enforcement is enabled, either tenant-wide or with a custom placeholder application.

    .DESCRIPTION
    Sign-ins that request only baseline scopes (the OpenID Connect scopes and basic directory scopes such as
    User.Read) were historically excluded from Conditional Access evaluation when an All resources policy had a
    resource exclusion. With the improved enforcement model these sign-ins are evaluated as directory access and
    are subject to Conditional Access like any other resource access.

    The tenant's selection in the Baseline scopes settings is stored as the resource application ID the baseline
    scopes are evaluated against. The check passes when enforcement is enabled (the Windows Azure Active Directory
    application). It asks for investigation when the Customize behavior option points at a custom placeholder
    application, listing the Conditional Access policies that target All resources and exclude it and so retain
    the legacy behavior, and
    when no choice is stored, because enforcement then comes from Microsoft's staged rollout and cannot be
    confirmed from the tenant. It fails when enforcement has been explicitly disabled, and lists the enabled
    policies that target All resources and have a resource exclusion, because those keep the legacy behavior.

    It also fails, whatever the selection, when an enabled Conditional Access policy excludes Windows Azure Active
    Directory although it includes it, either through All resources or directly. With certain public client IDs that are
    allowed to request this resource, an attacker with valid credentials can then obtain a directory token and
    access directory data without meeting the policy, which is a wider gap than the legacy behavior for baseline
    scopes. An enabled policy that excludes Windows Azure Active Directory without including it is listed for
    investigation, because the exclusion opens the gap as soon as the policy's scope is widened.

    It is skipped when the Conditional Access settings cannot be read because of missing permissions.

    Learn more:
    https://learn.microsoft.com/entra/identity/conditional-access/concept-enforcement-resource-exclusions

    .EXAMPLE
    Test-MtCaBaselineScopesEnforcement

    .LINK
    https://maester.dev/docs/tests/MT.1259
    #>
    [MaesterTest(
        Id = 'MT.1259',
        Title = 'Conditional Access baseline scopes enforcement should be enabled.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1087.004'),
        Control = 'nist-800-53-r5:AC-3',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Lifecycle = 'Preview',
        Author = 'dustinscholl'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    # The Baseline scopes settings store the tenant's choice as the resource application ID that baseline scope
    # sign-ins are evaluated against:
    #   null or missing                        - no choice stored; enforcement comes from the staged rollout
    #   00000000-0000-0000-0000-000000000000   - Disable enforcement
    #   00000002-0000-0000-c000-000000000000   - Enable enforcement (Windows Azure Active Directory)
    #   any other application ID               - Customize behavior with a custom placeholder application
    $enforcedResourceAppId = '00000002-0000-0000-c000-000000000000'
    $disabledResourceAppId = '00000000-0000-0000-0000-000000000000'
    # Deep link to the Baseline scopes settings in the Entra admin center; the page is only reachable through this link.
    $settingsUrl = 'https://aka.ms/BaselineScopesSettingsUX'

    try {
        $settings = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/settings' -ApiVersion beta -ErrorAction Stop
    } catch {
        $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        if ($statusCode -notin 401, 403) { throw }
        # Without the setting there is nothing to evaluate.
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }
    $resourceAppId = $settings.advancedSettings.baselineScopes.resourceAppId
    Write-Verbose "Baseline scopes resourceAppId: '$resourceAppId'"

    $enabledPolicies = @(Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq 'enabled' })

    # Excluding Windows Azure Active Directory from a policy that includes it takes directory access out of the
    # policy, so it fails the check whatever the baseline scopes selection is. In a policy that does not include
    # it, the exclusion has no effect today but opens the gap as soon as the policy's scope is widened.
    $directoryExcludingPolicies = @()
    $inactiveDirectoryExclusions = @()
    foreach ($policy in $enabledPolicies) {
        $applications = $policy.conditions.applications
        if ($applications.excludeApplications -notcontains $enforcedResourceAppId) { continue }
        if ($applications.includeApplications -contains 'All' -or $applications.includeApplications -contains $enforcedResourceAppId) {
            $directoryExcludingPolicies += $policy
        } else {
            $inactiveDirectoryExclusions += $policy
        }
    }

    $inactiveExclusionNote = ''
    if ($inactiveDirectoryExclusions.Count -gt 0) {
        $inactiveExclusionNote = "`n`nThe following enabled policies exclude **Windows Azure Active Directory** but do not include it, so the exclusion has no effect today. Remove the exclusion so that it cannot open a gap if the policy's scope is widened:`n`n" +
        (Get-GraphObjectMarkdown -GraphObjects $inactiveDirectoryExclusions -GraphObjectType ConditionalAccess)
    }

    if ($directoryExcludingPolicies.Count -gt 0) {
        $testResult = "The following enabled Conditional Access policies exclude **Windows Azure Active Directory** (``$enforcedResourceAppId``), although they include it, either through All resources or directly. With certain public client IDs that are allowed to request this resource, an attacker with valid credentials can obtain a directory token and access users, groups, devices, applications and role memberships without meeting these policies' requirements. Remove this exclusion. If an excluded application must keep the legacy behavior for baseline scopes, use **Customize behavior** with a placeholder application in the [Baseline scopes settings]($settingsUrl) instead.`n`n%TestResult%" + $inactiveExclusionNote
        Add-MtTestResultDetail -Result $testResult -GraphObjects $directoryExcludingPolicies -GraphObjectType ConditionalAccess
        return $false
    }

    if ([string]::IsNullOrEmpty($resourceAppId)) {
        $testResult = "No baseline scopes enforcement choice is stored in this tenant. Microsoft enables enforcement by default through its staged rollout, which started on June 15, 2026, but whether it has reached this tenant cannot be confirmed from the tenant. Make the choice explicit in the [Baseline scopes settings]($settingsUrl): **Enable enforcement**, or **Customize behavior** if specific policies must retain the legacy behavior." + $inactiveExclusionNote
        Add-MtTestResultDetail -Result $testResult -Investigate
        return $true
    }

    # Only policies that target All resources and have a resource exclusion keep the legacy behavior.
    $allResourcesPolicies = @($enabledPolicies | Where-Object {
            $_.conditions.applications.includeApplications -contains 'All'
        })

    if ($resourceAppId -eq $disabledResourceAppId) {
        $testResult = "Baseline scopes enforcement is explicitly **disabled** in this tenant. Sign-ins that request only baseline scopes bypass every All resources Conditional Access policy that has a resource exclusion. Change the choice in the [Baseline scopes settings]($settingsUrl): **Enable enforcement**, or **Customize behavior** if specific policies must retain the legacy behavior."
        $affectedPolicies = @($allResourcesPolicies | Where-Object {
                @($_.conditions.applications.excludeApplications | Where-Object { $_ }).Count -gt 0
            })
        if ($affectedPolicies.Count -gt 0) {
            $testResult += "`n`nThe following enabled policies target All resources and have a resource exclusion, so they currently do not evaluate these sign-ins. Review them before you change the setting:`n`n%TestResult%" + $inactiveExclusionNote
            Add-MtTestResultDetail -Result $testResult -GraphObjects $affectedPolicies -GraphObjectType ConditionalAccess
        } else {
            $testResult += "`n`nNo enabled policy currently targets All resources with a resource exclusion, so enabling enforcement does not change any sign-in today." + $inactiveExclusionNote
            Add-MtTestResultDetail -Result $testResult
        }
        return $false
    }

    if ($resourceAppId -eq $enforcedResourceAppId) {
        $testResult = "Baseline scopes enforcement is enabled. Sign-ins that request only baseline scopes are evaluated against **Windows Azure Active Directory** and are subject to your Conditional Access policies."
        if ($inactiveExclusionNote) {
            Add-MtTestResultDetail -Result ($testResult + $inactiveExclusionNote) -Investigate
        } else {
            Add-MtTestResultDetail -Result "Well done. $testResult"
        }
        return $true
    }

    # Any other application ID is a custom placeholder application chosen with the Customize behavior option.
    # The lookup only adds a display name, so a missing permission falls back to the application ID.
    try {
        $placeholderApp = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -ApiVersion v1.0 -Filter "appId eq '$resourceAppId'" -Select id, displayName -ErrorAction Stop
    } catch {
        $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        if ($statusCode -notin 401, 403) { throw }
        $placeholderApp = $null
    }
    if ($placeholderApp.id) {
        $appLink = "[$($placeholderApp.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($placeholderApp.id)/appId/$resourceAppId)"
    } else {
        $appLink = "``$resourceAppId`` (no service principal found in this tenant, or no permission to read it)"
    }

    $excludingPolicies = @($allResourcesPolicies | Where-Object {
            $_.conditions.applications.excludeApplications -contains $resourceAppId
        })

    # Customize behavior is a deliberate opt-out for specific policies, so it is reported for review rather than as a pass.
    $testResult = "Baseline scopes enforcement is configured with the **Customize behavior** option. Sign-ins that request only baseline scopes are evaluated against the placeholder application $appLink."
    if ($excludingPolicies.Count -gt 0) {
        $testResult += "`n`nThe following enabled Conditional Access policies target All resources and exclude the placeholder application, and therefore retain the legacy behavior. Review whether each policy still needs the legacy behavior and its resource exclusions. If none does, select **Enable enforcement** in the [Baseline scopes settings]($settingsUrl).`n`n%TestResult%" + $inactiveExclusionNote
        Add-MtTestResultDetail -Result $testResult -GraphObjects $excludingPolicies -GraphObjectType ConditionalAccess -Investigate
    } else {
        $testResult += "`n`nNo enabled Conditional Access policy that targets All resources excludes the placeholder application, so no policy uses the legacy behavior and the customization has no effect. Review whether the Customize behavior option is still needed, and otherwise select **Enable enforcement** in the [Baseline scopes settings]($settingsUrl) as the stronger default." + $inactiveExclusionNote
        Add-MtTestResultDetail -Result $testResult -Investigate
    }
    return $true
}
