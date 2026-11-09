function Test-MtCrossTenantAdministrationRelationship {
    <#
    .SYNOPSIS
    Checks that only allowlisted tenants administer this tenant through Tenant Governance or GDAP.

    .DESCRIPTION
    Two features let administrators of another Microsoft Entra tenant act in this tenant:

    - Microsoft Entra Tenant Governance: a governance relationship that is not terminated, in which this tenant is the governed
      tenant. Its policy assigns Microsoft Entra roles to groups of the governing tenant and can provision
      multitenant applications with their permissions.
    - Granular delegated admin privileges (GDAP): a Cloud Solution Provider (CSP) partner with a delegated admin
      relationship. The partner appears as a service provider in the cross-tenant access settings, and its
      security groups hold Microsoft Entra roles in this tenant.

    Governing tenants (any relationship status except terminated) and GDAP partner tenants identified through remote tenant groups must be listed in
    DelegatedAdminTenants. Without the setting no tenant is allowlisted. Legacy DAP, unrelated foreign role
    assignments and cross-tenant service provider marks do not affect the verdict. The service provider mark can
    remain after a relationship ends and is shown only for information.

    Remote tenant groups are, to the best of current knowledge, the strongest customer-side signal that names a GDAP
    partner, so they are the only GDAP anchor. The two GDAP service principals that Microsoft creates in the customer
    tenant do not name the partner either: "Partner customer delegated admin offline processor"
    (a3475900-ccec-4a69-98f5-a65cd5dc5306) is documented to be removed when the last GDAP relationship ends, and
    "Partner customer delegated administration" (2832473f-ec63-45fb-976f-5d45a7d4bb91) is required when a
    relationship is accepted and sets up the service provider mark. The delegatedAdminRelationships API is readable
    only by the partner. The .md compares the signals. Source:
    https://learn.microsoft.com/partner-center/customers/gdap-migration-faq#what-are-the-two-microsoft-entra-gdap-service-principals-that-are-created-in-the-customer-s-tenant-

    Related tenant discovery optionally enriches the result with inbound admin-app user and application counts.
    It is enabled by default and is skipped when Microsoft Entra ID Governance licensing cannot be confirmed.
    Discovery and other enrichment failures are reported but do not affect the verdict. An unreadable governance
    relationship or remote tenant group source makes an otherwise passing result Investigate. Remote groups of a
    former governing tenant also need investigation because their GDAP origin cannot be confirmed.

    Learn more:
    https://learn.microsoft.com/entra/id-governance/tenant-governance/governance-relationships
    https://learn.microsoft.com/partner-center/customers/gdap-introduction

    .EXAMPLE
    Test-MtCrossTenantAdministrationRelationship

    .LINK
    https://maester.dev/docs/tests/MT.1258
    #>
    [MaesterTest(
        Id = 'MT.1258',
        Title = 'Only allowlisted tenants can administer this tenant through GDAP or Tenant Governance.',
        Product = 'entra',
        RelatedProduct = 'microsoft-365',
        Feature = 'external-identities',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1199',
        Control = 'nist-800-53-r5:AC-6(5)',
        Service = 'Graph',
        Permission = ('Graph:Scope:Directory.Read.All', 'Graph:Scope:TenantGovernance-Relationship.Read.All', 'Graph:Scope:RemoteTenantGroups.Read.All'),
        Cloud = ('Commercial', 'GCC'),
        Lifecycle = 'Preview',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Include informational inbound admin-app user and application counts when Governance licensing is available.
        [bool] $IncludeTenantDiscovery = $true
    )

    # Tenant Governance and remote tenant groups are only available in the worldwide Microsoft Graph service. The Cloud
    # attribute is enforced only when the run config turns it on, so the check also skips itself outside Global.
    $graphEnvironment = (Get-MgContext).Environment
    if ($graphEnvironment -and $graphEnvironment -ne 'Global') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Tenant Governance is not available in the $graphEnvironment cloud."
        return $null
    }

    $entraPortal = $__MtSession.AdminPortalUrl.Entra
    $nowUtc = (Get-Date).ToUniversalTime()
    # Microsoft 365 admin center > Settings > Partner relationships (the fwlink Microsoft documents for customers).
    $partnerRelationshipsUrl = 'https://go.microsoft.com/fwlink/p/?linkid=2074649'

    $describeError = {
        param($ErrorRecord)
        $statusCode = if ($ErrorRecord.Exception.Response) { [int]$ErrorRecord.Exception.Response.StatusCode } else { $null }
        $message = ("$($ErrorRecord.Exception.Message)" -split '\r?\n')[0].TrimEnd('.', ' ')
        if ($message.Length -gt 160) { $message = $message.Substring(0, 160) + '…' }
        [pscustomobject]@{
            StatusCode = $statusCode
            Text       = "$(if ($statusCode) { "HTTP $($statusCode): " })$message" -replace '\|', '\|'
        }
    }
    $toUtc = {
        param($Value)
        if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
        if ($Value -is [datetimeoffset]) { return $Value.UtcDateTime }
        $parsed = [datetimeoffset]::MinValue
        if ($Value -and [datetimeoffset]::TryParse("$Value", [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)) {
            return $parsed.UtcDateTime
        }
        return $null
    }
    $formatDate = {
        param($Value)
        $date = & $toUtc $Value
        if (-not $date) { return 'Unknown' }
        $days = [int][math]::Floor(($nowUtc - $date).TotalDays)
        $age = if ($days -lt 1) { 'today' } elseif ($days -eq 1) { '1 day ago' } else { "$days days ago" }
        "$($date.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)) ($age)"
    }

    $ownTenantId = "$(@(Invoke-MtGraphRequest -RelativeUri 'organization' -Select 'id')[0].id)"
    $sourceErrors = [System.Collections.Generic.List[object]]::new()
    $informationErrors = [System.Collections.Generic.List[object]]::new()

    # Tenant Governance: relationships that are not terminated in which this tenant is governed. Every tenant that takes part in a
    # governance relationship, whatever its status, is remembered: governance relationships use cross-tenant GDAP,
    # so the cross-tenant access settings mark those tenants as service providers too, even after termination.
    $governance = @()
    $formerGoverningIds = @()
    $governanceTenantIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $allGovernance = @(Invoke-MtGraphRequest -RelativeUri 'directory/tenantGovernance/governanceRelationships' -ApiVersion beta -ErrorAction Stop)
        foreach ($relationship in $allGovernance) {
            foreach ($tenantId in @("$($relationship.governingTenantId)", "$($relationship.governedTenantId)") | Where-Object { $_ -and $_ -ne $ownTenantId }) {
                $null = $governanceTenantIds.Add($tenantId)
            }
        }
        # Only a terminated relationship has ended: one whose termination is requested still grants its roles, and
        # an unknown future status is treated as current rather than silently passing.
        $governance = @($allGovernance |
            Where-Object { $_.status -ne 'terminated' -and "$($_.governedTenantId)" -eq $ownTenantId -and "$($_.governingTenantId)" -ne $ownTenantId } |
            Sort-Object -Property { & $toUtc $_.creationDateTime })
        # Tenants that governed this tenant only in relationships that have been terminated.
        $activeGoverningIds = @($governance | ForEach-Object { "$($_.governingTenantId)" })
        $formerGoverningIds = @($allGovernance |
            Where-Object { $_.status -eq 'terminated' -and "$($_.governedTenantId)" -eq $ownTenantId -and $_.governingTenantId -and "$($_.governingTenantId)" -ne $ownTenantId } |
            ForEach-Object { "$($_.governingTenantId)" } | Where-Object { $_ -notin $activeGoverningIds } | Select-Object -Unique)
    } catch {
        $sourceErrors.Add([pscustomobject]@{ Source = 'Tenant Governance relationships'; Error = (& $describeError $_) })
    }

    # Service provider marks can outlive the relationship and never determine the verdict.
    $allServiceProviderIds = @()
    try {
        $allServiceProviderIds = @(Invoke-MtGraphRequest -RelativeUri 'policies/crossTenantAccessPolicy/partners' -ApiVersion v1.0 -ErrorAction Stop |
            Where-Object { $_.isServiceProvider -eq $true -and $_.tenantId -and "$($_.tenantId)" -ne $ownTenantId } | ForEach-Object { "$($_.tenantId)" } | Select-Object -Unique)
    } catch {
        $informationErrors.Add([pscustomobject]@{ Source = 'cross-tenant access partners'; Error = (& $describeError $_) })
    }

    # Partner metadata and legacy DAP roles are informational, not evidence of GDAP.
    $directoryPartners = @()
    try {
        $directoryPartners = @(Invoke-MtGraphRequest -RelativeUri 'directory/partners' -ApiVersion beta -ErrorAction Stop |
            Where-Object { $_.partnerTenantId -and "$($_.partnerTenantId)" -ne $ownTenantId })
    } catch {
        $informationErrors.Add([pscustomobject]@{ Source = 'CSP partner information'; Error = (& $describeError $_) })
    }

    # Groups of other tenants that hold access in this tenant, such as the admin groups of a GDAP partner. They
    # name the group and its tenant for the role assignments below.
    $remoteGroupById = @{}
    try {
        foreach ($remoteGroup in @(Invoke-MtGraphRequest -RelativeUri 'directory/remoteTenantGroups' -ApiVersion beta -ErrorAction Stop)) {
            foreach ($key in @("$($remoteGroup.id)", "$($remoteGroup.remoteGroupId)") | Where-Object { $_ }) { $remoteGroupById[$key] = $remoteGroup }
        }
    } catch {
        $sourceErrors.Add([pscustomobject]@{ Source = 'remote tenant groups'; Error = (& $describeError $_) })
    }

    # Directory roles held by principals of another tenant: the groups of a GDAP partner or a governing tenant. A
    # principal belongs to another tenant when principalOrganizationId names it, or when it is a remote tenant group.
    $foreignAssignments = @()
    $roleNames = @{}
    $privilegedRoles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $foreignAssignments = @(Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleAssignments' -ApiVersion beta `
                -Select 'id', 'principalId', 'principalOrganizationId', 'roleDefinitionId', 'directoryScopeId' -ErrorAction Stop | ForEach-Object {
                $foreignTenantId = if ($_.principalOrganizationId -and "$($_.principalOrganizationId)" -ne $ownTenantId) { "$($_.principalOrganizationId)" }
                elseif ($remoteGroupById.ContainsKey("$($_.principalId)")) { "$($remoteGroupById["$($_.principalId)"].remoteTenantId)" }
                else { $null }
                if ($foreignTenantId) {
                    [pscustomobject]@{ TenantId = $foreignTenantId; principalId = "$($_.principalId)"; roleDefinitionId = "$($_.roleDefinitionId)"; directoryScopeId = $_.directoryScopeId }
                }
            })
        foreach ($definition in @(Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion beta `
                    -Select 'id', 'templateId', 'displayName', 'isPrivileged' -ErrorAction Stop)) {
            foreach ($key in @($definition.id, $definition.templateId) | Where-Object { $_ }) {
                $roleNames[$key] = $definition.displayName
                if ($definition.isPrivileged -eq $true) { $null = $privilegedRoles.Add($key) }
            }
        }
    } catch {
        $informationErrors.Add([pscustomobject]@{ Source = 'directory role information'; Error = (& $describeError $_) })
    }

    # Admin app sign-ins: Tenant Governance related tenant discovery reports, per related tenant, how many users of
    # that tenant signed in to the predefined Microsoft admin portals of this tenant in the last month. Discovery
    # needs Microsoft Entra ID Governance (service plan Entra_Identity_Governance) and must be turned on.
    $hasGovernanceLicense = $false
    $licenseError = $null
    if ($IncludeTenantDiscovery) {
        try {
            $hasGovernanceLicense = @(Invoke-MtGraphRequest -RelativeUri 'subscribedSkus' -ErrorAction Stop | Where-Object { $_.capabilityStatus -eq 'Enabled' } |
                ForEach-Object { $_.servicePlans.servicePlanId }) -contains 'e866a266-3cff-43a3-acca-0c90a7e00c8b'
        } catch {
            $licenseError = & $describeError $_
        }
    }
    $adminSignIns = @{}
    $relatedTenantIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $microsoftTenantIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $relatedError = $null
    $related = @()
    if ($IncludeTenantDiscovery -and $hasGovernanceLicense) {
        try {
            $related = @(Invoke-MtGraphRequest -RelativeUri 'directory/tenantGovernance/relatedTenants' -ApiVersion v1.0 -ErrorAction Stop | Where-Object { $_.id })
        } catch {
            $relatedError = & $describeError $_
        }
    }
    foreach ($relatedTenant in $related) {
        $null = $relatedTenantIds.Add("$($relatedTenant.id)")
        if ($relatedTenant.isMicrosoftInfrastructure -eq $true) { $null = $microsoftTenantIds.Add("$($relatedTenant.id)") }
        $metrics = $relatedTenant.appB2BSignInActivityMetrics
        $snapshot = if ($metrics.recent) { $metrics.recent } elseif ($metrics.initial) { $metrics.initial } else { $null }
        if ($snapshot) { $adminSignIns["$($relatedTenant.id)"] = $snapshot }
    }
    $adminSignInsUnavailable = if (-not $IncludeTenantDiscovery) {
        'tenant discovery is disabled by IncludeTenantDiscovery'
    } elseif ($licenseError) {
        "tenant discovery was skipped because Governance licensing could not be confirmed ($($licenseError.Text))"
    } elseif (-not $hasGovernanceLicense) {
        'tenant discovery was skipped because the tenant has no Microsoft Entra ID Governance licence'
    } elseif ($relatedError) {
        "the related tenants could not be read ($($relatedError.Text))"
    } elseif ($related.Count -eq 0) {
        'Tenant Governance reports no related tenants. Related tenant discovery may not be turned on (**Tenant governance** > **Related tenants**)'
    } else { $null }
    $formatAdminSignIns = {
        param([string] $TenantId)
        if ($adminSignInsUnavailable) { return '—' }
        if (-not $adminSignIns.ContainsKey($TenantId)) { return 'Not available' }
        $users = [int]$adminSignIns[$TenantId].inboundMonthlyTotalUsers
        $apps = [int]$adminSignIns[$TenantId].inboundMonthlyTotalApplications
        if ($users -eq 0 -and $apps -eq 0) { return 'None' }
        "🔑 $users $(if ($users -eq 1) { 'user' } else { 'users' }) · $apps admin $(if ($apps -eq 1) { 'app' } else { 'apps' })"
    }
    $testPrivilegedRole = {
        param([string] $Id, [string] $Name)
        # Microsoft Graph's isPrivileged decides for the roles it returned; Maester's role table only for the others.
        if ($roleNames.ContainsKey($Id)) { return $privilegedRoles.Contains($Id) }
        $display = if ($Name) { $Name } else { $Id }
        $roleInfo = Get-MtRoleInfo -RoleName ($display -replace '[^A-Za-z0-9]', '')
        [bool]($roleInfo -and $roleInfo.IsPrivileged)
    }
    $formatRole = {
        param([string] $Id, [string] $Name)
        $display = if ($Name) { $Name } elseif ($roleNames.ContainsKey($Id)) { $roleNames[$Id] } else { $Id }
        $safe = Get-MtSafeMarkdown $display
        if (& $testPrivilegedRole $Id $display) { "🚨 **$safe**" } else { $safe }
    }

    # Only the two assessment sources determine completeness; enrichment cannot prove a pass.
    if ($sourceErrors.Count -eq 2) {
        if (@($sourceErrors | Where-Object { $_.Error.StatusCode -in @(401, 403) }).Count -eq $sourceErrors.Count) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw "None of the relationship sources could be read: $(($sourceErrors | ForEach-Object { "$($_.Source) ($($_.Error.Text))" }) -join '; ')"
    }

    # Display names of tenants that the relationships do not name, such as GDAP partners.
    $tenantNames = @{}
    foreach ($relationship in $governance) { $tenantNames["$($relationship.governingTenantId)"] = $relationship.governingTenantName }
    foreach ($remoteGroup in $remoteGroupById.Values) {
        if ($remoteGroup.remoteTenantId -and $remoteGroup.remoteTenantDisplayName -and -not $tenantNames["$($remoteGroup.remoteTenantId)"]) {
            $tenantNames["$($remoteGroup.remoteTenantId)"] = "$($remoteGroup.remoteTenantDisplayName)$(if ($remoteGroup.remoteTenantPrimaryDomain) { " ($($remoteGroup.remoteTenantPrimaryDomain))" })"
        }
    }
    foreach ($partner in $directoryPartners) {
        if ($partner.companyName -and -not $tenantNames["$($partner.partnerTenantId)"]) { $tenantNames["$($partner.partnerTenantId)"] = $partner.companyName }
    }
    $lookupTenant = {
        param([string] $TenantId)
        if ($tenantNames.ContainsKey($TenantId) -and $tenantNames[$TenantId]) { return $tenantNames[$TenantId] }
        try {
            $info = Invoke-MtGraphRequest -RelativeUri "tenantRelationships/findTenantInformationByTenantId(tenantId='$TenantId')" -ApiVersion v1.0 -ErrorAction Stop
            $name = if ($info.displayName) { "$($info.displayName)$(if ($info.defaultDomainName) { " ($($info.defaultDomainName))" })" } else { $null }
        } catch {
            Write-Verbose "Could not look up tenant $($TenantId): $($_.Exception.Message)"
            $name = $null
        }
        $tenantNames[$TenantId] = $name
        $name
    }
    # Allowlisted tenants: the DelegatedAdminTenants setting, like EmergencyAccessAccounts a list in the GlobalSettings
    # of maester-config.json. Each entry is a tenant ID as a string.
    $allowlistedTenantIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $allowlistEntries = Get-MtSetting -Name 'DelegatedAdminTenants'
    foreach ($entry in @($allowlistEntries | Where-Object { $null -ne $_ -and "$_" -ne '' })) {
        $parsedTenantId = [guid]::Empty
        if ($entry -isnot [string] -or -not [guid]::TryParse($entry.Trim(), [ref]$parsedTenantId)) {
            Write-Warning "MT.1258: an entry of the DelegatedAdminTenants setting is not a tenant ID and is ignored: $(ConvertTo-Json -InputObject $entry -Compress -Depth 3). Write each tenant ID as a string."
            continue
        }
        # The parsed form, so that braced or unhyphenated entries match the hyphenated IDs that Graph returns.
        $null = $allowlistedTenantIds.Add($parsedTenantId.ToString())
    }
    $allowlistConfigured = $allowlistedTenantIds.Count -gt 0
    $formatTenant = {
        param([string] $TenantId, [string] $Name, [string] $Url, [switch] $NoMarker)
        $label = if ($Name) { Get-MtSafeMarkdown $Name } else { 'Unknown tenant' }
        $linked = if ($Url) { "[$label]($Url)" } else { $label }
        $marker = if (-not $NoMarker -and $notAllowlistedSet -and $notAllowlistedSet.Contains($TenantId)) { '❌ **Not allowlisted** · ' } else { '' }
        "$marker🏢 $linked · ``$TenantId``"
    }

    # The first successful change to an object that the audit log records, and who made it. Which audit activity
    # approves a relationship is not confirmed, and the audit log keeps entries only within its retention (30 days by
    # default), so this is shown as the first recorded change, not as proof of who approved the relationship.
    # Found is $false when the log could not be read or holds no successful change for the object.
    $findFirstChange = {
        param([string] $TargetId)
        try {
            # -DisablePaging keeps the lookup to one page of 10 events, and returns the raw response: the events are in .value.
            $response = Invoke-MtGraphRequest -RelativeUri 'auditLogs/directoryAudits' -ApiVersion v1.0 `
                -Filter "targetResources/any(t:t/id eq '$TargetId')" -QueryParameters @{ '$orderby' = 'activityDateTime asc'; '$top' = '10' } -DisablePaging -ErrorAction Stop
            $audit = @($response.value)
        } catch {
            Write-Verbose "Could not read the audit log for $($TargetId): $($_.Exception.Message)"
            return [pscustomobject]@{ Found = $false; Text = '_Audit log not available_' }
        }
        # A failed or rejected attempt did not change the object.
        $entry = $audit | Where-Object {
            "$($_.result)" -eq 'success' -and ($_.initiatedBy.user.userPrincipalName -or $_.initiatedBy.user.displayName -or $_.initiatedBy.app.displayName)
        } | Select-Object -First 1
        if (-not $entry) { return [pscustomobject]@{ Found = $false; Text = '_No successful change found in the audit log_' } }
        $who = if ($entry.initiatedBy.user.userPrincipalName) { "👤 $(Get-MtSafeMarkdown $entry.initiatedBy.user.userPrincipalName)" }
        elseif ($entry.initiatedBy.user.displayName) { "👤 $(Get-MtSafeMarkdown $entry.initiatedBy.user.displayName)" }
        else { "🧩 $(Get-MtSafeMarkdown $entry.initiatedBy.app.displayName)" }
        $date = & $toUtc $entry.activityDateTime
        $dateText = if ($date) { $date.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture) } else { 'an unknown date' }
        [pscustomobject]@{ Found = $true; Text = "$who · $(Get-MtSafeMarkdown $entry.activityDisplayName) on $dateText" }
    }

    $assignmentsByTenant = @{}
    foreach ($assignment in $foreignAssignments) {
        $tenantId = "$($assignment.TenantId)"
        if (-not $assignmentsByTenant.ContainsKey($tenantId)) { $assignmentsByTenant[$tenantId] = [System.Collections.Generic.List[object]]::new() }
        $assignmentsByTenant[$tenantId].Add($assignment)
    }
    $formatAssignedRoles = {
        param([string] $TenantId)
        if ($assignmentsByTenant.ContainsKey($TenantId)) {
            $byGroup = $assignmentsByTenant[$TenantId] | Group-Object -Property principalId
            return @($byGroup | ForEach-Object {
                    $roles = @($_.Group | Sort-Object -Property roleDefinitionId -Unique | ForEach-Object { & $formatRole "$($_.roleDefinitionId)" $null } | Sort-Object)
                    $scopes = @($_.Group | Where-Object { $_.directoryScopeId -and $_.directoryScopeId -ne '/' })
                    $group = if ($remoteGroupById.ContainsKey($_.Name) -and $remoteGroupById[$_.Name].remoteGroupDisplayName) { Get-MtSafeMarkdown $remoteGroupById[$_.Name].remoteGroupDisplayName } else { "``$($_.Name)``" }
                    "👥 $($group): $($roles -join ', ')$(if ($scopes.Count -gt 0) { ' (scoped)' })"
                }) -join ' \| '
        }
        # The groups of a GDAP partner are known as remote tenant groups, but their roles are not directory role
        # assignments of this tenant: list the groups, and leave the roles to the Partner relationships page.
        $groups = @($remoteGroupById.Values | Where-Object { "$($_.remoteTenantId)" -eq $TenantId } | Sort-Object -Property id -Unique |
            ForEach-Object { if ($_.remoteGroupDisplayName) { $_.remoteGroupDisplayName } else { $_.remoteGroupId } } | Sort-Object)
        if ($groups.Count -gt 0) {
            return "$(@($groups | ForEach-Object { "👥 $(Get-MtSafeMarkdown $_)" }) -join ', ') · _roles shown on the [Partner relationships]($partnerRelationshipsUrl) page_"
        }
        '_None found_'
    }

    $governingIds = @($governance | ForEach-Object { "$($_.governingTenantId)" })
    # Remote tenant groups are exposed after delegated privileges are established through Partner Center or
    # Tenant Governance. Exclude governance tenants rather than using stale service provider marks to infer GDAP.
    $remoteGroupTenantIds = @($remoteGroupById.Values | ForEach-Object { "$($_.remoteTenantId)" } | Where-Object { $_ } | Select-Object -Unique)
    # Active governing tenants are assessed above and former governing tenants are investigated below; a tenant that
    # this tenant governs has no governance path in, so its remote groups still count as GDAP.
    $providerIds = @($remoteGroupTenantIds | Where-Object { $_ -ne $ownTenantId -and $_ -notin $governingIds -and $_ -notin $formerGoverningIds })
    # Tenants whose users signed in to the admin portals of this tenant, other than Microsoft's own infrastructure.
    $adminActiveIds = @($adminSignIns.Keys | Where-Object {
            $_ -ne $ownTenantId -and -not $microsoftTenantIds.Contains($_) -and
            ([int]$adminSignIns[$_].inboundMonthlyTotalUsers -gt 0 -or [int]$adminSignIns[$_].inboundMonthlyTotalApplications -gt 0)
        })
    # Privileged Microsoft Entra roles each tenant holds in this tenant: through a Tenant Governance policy, a
    # directory role assignment or legacy DAP roles. GDAP roles are not visible from this tenant.
    $privilegedByTenant = @{}
    $markPrivileged = {
        param([string] $TenantId, [string] $RoleId, [string] $RoleName)
        if ($TenantId -and $RoleId -and (& $testPrivilegedRole $RoleId $RoleName)) {
            if (-not $privilegedByTenant.ContainsKey($TenantId)) { $privilegedByTenant[$TenantId] = [System.Collections.Generic.List[string]]::new() }
            $display = if ($RoleName) { $RoleName } elseif ($roleNames.ContainsKey($RoleId)) { $roleNames[$RoleId] } else { $RoleId }
            if (-not $privilegedByTenant[$TenantId].Contains($display)) { $privilegedByTenant[$TenantId].Add($display) }
        }
    }
    foreach ($relationship in $governance) {
        foreach ($assignment in @($relationship.policySnapshot.delegatedAdministrationRoleAssignments | Where-Object { $null -ne $_ })) {
            foreach ($template in @($assignment.roleTemplates | Where-Object { $null -ne $_ })) { & $markPrivileged "$($relationship.governingTenantId)" "$($template.id)" "$($template.name)" }
        }
    }
    foreach ($tenantId in $assignmentsByTenant.Keys) {
        foreach ($assignment in $assignmentsByTenant[$tenantId]) { & $markPrivileged $tenantId "$($assignment.roleDefinitionId)" $null }
    }
    foreach ($partner in $directoryPartners) {
        foreach ($roleId in @($partner.roleIds | Where-Object { $_ })) { & $markPrivileged "$($partner.partnerTenantId)" "$roleId" $null }
    }

    $accessTenantIds = @(@($governingIds) + @($providerIds) | Where-Object { $_ -and $_ -ne $ownTenantId } | Select-Object -Unique)
    $notAllowlisted = @($accessTenantIds | Where-Object { -not $allowlistedTenantIds.Contains($_) })
    $notAllowlistedSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($notAllowlisted), [System.StringComparer]::OrdinalIgnoreCase)
    $notAllowlistedPrivileged = @($notAllowlisted | Where-Object { $privilegedByTenant.ContainsKey($_) })
    $allowlistedWithAccess = @($accessTenantIds | Where-Object { $allowlistedTenantIds.Contains($_) })
    $allowlistedWithoutAccess = @($allowlistedTenantIds | Where-Object { $_ -notin $accessTenantIds } | Sort-Object)
    $shownGovernance = @($governance | Where-Object { -not $allowlistedTenantIds.Contains("$($_.governingTenantId)") })
    $shownProviderIds = @($providerIds | Where-Object { -not $allowlistedTenantIds.Contains($_) })
    $tenantLabel = {
        param([string] $TenantId)
        $name = & $lookupTenant $TenantId
        if ($name) { "$(Get-MtSafeMarkdown $name) ($('`{0}`' -f $TenantId))" } else { '`{0}`' -f $TenantId }
    }

    if ($notAllowlisted.Count -eq 0) {
        $testResultMarkdown = if ($sourceErrors.Count -gt 0) {
            'No tenant that is not allowlisted was found, but not every source could be read, so this can be incomplete.'
        } elseif ($accessTenantIds.Count -eq 0) {
            'Well done. No governing tenant or GDAP partner with remote tenant groups was found. Legacy DAP and unrelated Microsoft Entra role assignments are outside this assessment.'
        } else {
            "Well done. All $($accessTenantIds.Count) $(if ($accessTenantIds.Count -eq 1) { 'tenant' } else { 'tenants' }) identified through GDAP or active Tenant Governance are allowlisted in ``DelegatedAdminTenants``."
        }
    } else {
        $parts = @(
            $governanceCount = @($notAllowlisted | Where-Object { $_ -in $governingIds }).Count
            $partnerCount = @($notAllowlisted | Where-Object { $_ -in $providerIds }).Count
            if ($governanceCount -gt 0) { "$governanceCount through Tenant Governance" }
            if ($partnerCount -gt 0) { "$partnerCount through GDAP" }
        )
        $testResultMarkdown = "❌ **$(if ($notAllowlisted.Count -eq 1) { '1 tenant has' } else { "$($notAllowlisted.Count) tenants have" }) delegated admin access to this tenant without being allowlisted in ``DelegatedAdminTenants``** ($($parts -join ', ')): $(@($notAllowlisted | ForEach-Object { & $tenantLabel $_ }) -join ', '). Remove the relationship if it is not needed, or add the tenant to ``DelegatedAdminTenants`` if it is allowed to administer this tenant."
        if (-not $allowlistConfigured) {
            $testResultMarkdown += " No tenant is allowlisted yet: list the tenants allowed to administer this tenant in the ``DelegatedAdminTenants`` setting in the ``GlobalSettings`` of ``maester-config.json``."
        }
        if ($notAllowlistedPrivileged.Count -gt 0) {
            $privilegedText = @($notAllowlistedPrivileged | ForEach-Object {
                    $name = & $lookupTenant $_
                    $label = if ($name) { Get-MtSafeMarkdown $name } else { '`{0}`' -f $_ }
                    $roles = @($privilegedByTenant[$_] | Sort-Object | ForEach-Object { Get-MtSafeMarkdown $_ }) -join ', '
                    "$($label): $roles"
                }) -join '; '
            $testResultMarkdown += "`n`n🚨 **Tenants that are not allowlisted hold privileged Microsoft Entra roles in this tenant ($privilegedText). An attacker who compromises such a tenant can use these roles to take over this tenant. Review them first.**"
        }
    }
    if ($allowlistedWithAccess.Count -gt 0) {
        $testResultMarkdown += "`n`n✅ $(if ($allowlistedWithAccess.Count -eq 1) { '1 allowlisted tenant has access and is' } else { "$($allowlistedWithAccess.Count) allowlisted tenants have access and are" }) not shown in the Tenant Governance and GDAP tables: $(@($allowlistedWithAccess | ForEach-Object { & $tenantLabel $_ }) -join ', ')."
    }
    if ($allowlistedWithoutAccess.Count -gt 0) {
        $allowlistedList = @($allowlistedWithoutAccess | ForEach-Object { & $tenantLabel $_ }) -join ', '
        $testResultMarkdown += "`n`nℹ️ Allowlisted in ``DelegatedAdminTenants`` but not found through active Tenant Governance or GDAP remote tenant groups: $allowlistedList. Verify the relationships before removing them from the list."
    }

    # Discovery enriches the report only; report skipped or unavailable metrics even when no tenants are listed.
    if ($adminSignInsUnavailable) {
        $testResultMarkdown += "`n`nℹ️ **Admin app sign-ins are not available:** $adminSignInsUnavailable. This does not affect the GDAP and Tenant Governance assessment."
    } else {
        $watermarks = @($adminSignIns.Values | ForEach-Object { & $toUtc $_.watermarkDateTime } | Where-Object { $_ })
        $asOf = if ($watermarks.Count -gt 0) { " Data as of $(($watermarks | Sort-Object -Descending | Select-Object -First 1).ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture))." } else { '' }
        $testResultMarkdown += "`n`n🔑 **Admin app sign-ins** are a **specialized subset of B2B sign-ins** that occur when users **authenticate across tenants to predefined Microsoft Entra administrative applications.** These sign-ins usually indicate cross-tenant administrative activity, not just collaboration. The column shows the inbound users and admin apps of the last month, from Tenant Governance related tenant discovery.$asOf A tenant that holds privileged roles but has no admin app sign-ins may no longer need its access."
    }
    foreach ($sourceError in $sourceErrors) {
        $testResultMarkdown += "`n`n❔ The $($sourceError.Source) could not be read, so the list below can be incomplete ($($sourceError.Error.Text))."
    }
    foreach ($informationError in $informationErrors) {
        $testResultMarkdown += "`n`nℹ️ The $($informationError.Source) could not be read ($($informationError.Error.Text)). This informational data does not affect the assessment."
    }
    $formerGoverningToVerify = @($formerGoverningIds | Where-Object { $_ -in $remoteGroupTenantIds -and -not $allowlistedTenantIds.Contains($_) } | Sort-Object)
    if ($formerGoverningToVerify.Count -gt 0) {
        $testResultMarkdown += "`n`n❔ **Verify $(if ($formerGoverningToVerify.Count -eq 1) { 'this former governing tenant' } else { 'these former governing tenants' }):** $(@($formerGoverningToVerify | ForEach-Object { & $tenantLabel $_ }) -join ', '). Its Tenant Governance relationship is terminated, but remote tenant groups are still exposed. Their origin cannot be distinguished from GDAP: verify the [Partner relationships]($partnerRelationshipsUrl) page. A leftover service provider mark alone does not require investigation."
    }

    if ($shownGovernance.Count -gt 0) {
        $testResultMarkdown += "`n`n### 🏛️ Tenant Governance`n`n"
        $testResultMarkdown += "| Governing tenant | Established | First recorded change (audit log) | Roles granted (governing tenant group: roles) | Apps provisioned in this tenant | Admin app sign-ins (inbound) |`n| --- | --- | --- | --- | --- | --- |`n"
        foreach ($relationship in $shownGovernance) {
            $tenantId = "$($relationship.governingTenantId)"
            $url = if ($entraPortal) { "$($entraPortal)#view/Microsoft_Entra_TenantManagement/TenantDetails.ReactView/id/$tenantId/selectedTab/relationship" } else { $null }
            $created = "$(& $formatDate $relationship.creationDateTime)$(switch ($relationship.createdType) { 'approvedByAdmin' { ' · approved by an admin' } 'addOnTenant' { ' · created as add-on tenant' } default { '' } })"
            if ("$($relationship.status)" -ne 'active') { $created += " · ⚠️ status: $(Get-MtSafeMarkdown "$($relationship.status)") (roles remain until terminated)" }
            $roles = @($relationship.policySnapshot.delegatedAdministrationRoleAssignments | Where-Object { $null -ne $_ } | ForEach-Object {
                    $roleList = @($_.roleTemplates | Where-Object { $null -ne $_ } | ForEach-Object { & $formatRole "$($_.id)" "$($_.name)" } | Sort-Object)
                    "👥 $(Get-MtSafeMarkdown $(if ($_.groupDisplayName) { $_.groupDisplayName } else { $_.groupId })): $($roleList -join ', ')"
                })
            $apps = @($relationship.policySnapshot.multiTenantApplicationsToProvision | Where-Object { $null -ne $_ } | ForEach-Object {
                    $permissions = @($_.requiredResourceAccesses | ForEach-Object { $_.permissions } | Where-Object { $null -ne $_ })
                    $appRoles = @($permissions | Where-Object { $_.type -eq 'role' }).Count
                    $scopes = @($permissions | Where-Object { $_.type -ne 'role' }).Count
                    $appName = if ($_.displayName) { Get-MtSafeMarkdown $_.displayName } else { "``$($_.appId)``" }
                    "🧩 $appName ($appRoles application, $scopes delegated permissions)"
                })
            $rolesText = if ($roles.Count -gt 0) { $roles -join ' \| ' } else { '_None_' }
            $appsText = if ($apps.Count -gt 0) { $apps -join ' \| ' } else { '_None_' }
            $testResultMarkdown += "| $(& $formatTenant $tenantId $relationship.governingTenantName $url) | $created | $((& $findFirstChange "$($relationship.id)").Text) | $rolesText | $appsText | $(& $formatAdminSignIns $tenantId) |`n"
        }
    }

    $informationalPartnerIds = @($directoryPartners | ForEach-Object { "$($_.partnerTenantId)" } | Where-Object { $_ -notin $accessTenantIds } | Select-Object -Unique)
    $reportedPartnerIds = @(@($shownProviderIds) + @($informationalPartnerIds) | Select-Object -Unique)
    if ($reportedPartnerIds.Count -gt 0) {
        $partnerById = @{}
        foreach ($partner in $directoryPartners) { $partnerById["$($partner.partnerTenantId)"] = $partner }
        $formatPartnerType = {
            param($Partner)
            if (-not $Partner.companyType) { return $null }
            switch ("$($Partner.companyType)") {
                'microsoftSupport' { 'Microsoft support' }
                'syndicatePartner' { 'Syndication partner' }
                'breadthPartner' { 'Breadth partner' }
                'breadthPartnerDelegatedAdmin' { 'Breadth partner with delegated admin' }
                'resellerPartnerDelegatedAdmin' { 'Reseller with delegated admin' }
                'valueAddedResellerPartnerDelegatedAdmin' { 'Value-added reseller with delegated admin' }
                default { "$($Partner.companyType)" }
            }
        }
        $testResultMarkdown += "`n### 🤝 GDAP and informational CSP partners`n`n"
        $testResultMarkdown += "Only GDAP partners identified through remote tenant groups are assessed here. Legacy DAP roles and other CSP partner metadata are informational only.`n`n"
        $testResultMarkdown += "| Partner tenant | Relationship | Partner groups with access (roles where visible) | Admin app sign-ins (inbound) | Partner support |`n| --- | --- | --- | --- | --- |`n"
        foreach ($tenantId in @($reportedPartnerIds | Sort-Object -Property { & $lookupTenant $_ })) {
            $partner = $partnerById[$tenantId]
            $relationship = @(
                $partnerType = & $formatPartnerType $partner
                if ($partnerType) { "🤝 $partnerType" }
                if ($tenantId -in $providerIds) { '🔐 GDAP (remote tenant groups exposed)' }
                else { 'ℹ️ Informational only; no GDAP established by this check' }
                # Legacy delegated admin privileges (DAP) give the partner standing roles such as Global Administrator.
                $dapRoles = @($partner.roleIds | Where-Object { $_ })
                if ($dapRoles.Count -gt 0) { "⚠️ **Legacy DAP roles:** $(@($dapRoles | ForEach-Object { & $formatRole "$_" $null } | Sort-Object) -join ', ')" }
                $firstChange = & $findFirstChange $tenantId
                if ($firstChange.Found) { "📝 First recorded change: $($firstChange.Text)" }
            )
            $supportUri = $null
            $supportUrl = if ($partner.supportUrl -and [uri]::TryCreate("$($partner.supportUrl)".Trim(), [System.UriKind]::Absolute, [ref]$supportUri) -and $supportUri.Scheme -in 'http', 'https') {
                $supportUri.AbsoluteUri.Replace(')', '%29').Replace('|', '%7C')
            } else { $null }
            $support = @(
                if ($partner.supportTelephones) { "📞 $(Get-MtSafeMarkdown (@($partner.supportTelephones) -join ', '))" }
                if ($partner.supportEmails) { "✉️ $(Get-MtSafeMarkdown (@($partner.supportEmails) -join ', '))" }
                if ($supportUrl) { "🌐 [Support]($supportUrl)" }
            )
            $relationshipText = if ($relationship.Count -gt 0) { $relationship -join ' · ' } else { '_Unknown_' }
            $supportText = if ($support.Count -gt 0) { $support -join ' · ' } else { '—' }
            $testResultMarkdown += "| $(& $formatTenant $tenantId (& $lookupTenant $tenantId) $partnerRelationshipsUrl) | $relationshipText | $(& $formatAssignedRoles $tenantId) | $(& $formatAdminSignIns $tenantId) | $supportText |`n"
        }
        $testResultMarkdown += "`nEach GDAP relationship, with its authorized roles, expiration date, auto-extend setting and status, is shown on the [Partner relationships]($partnerRelationshipsUrl) page of the Microsoft 365 admin center. Microsoft Graph returns the relationships themselves only to the partner's tenant, so this check cannot show them or link to a single relationship.`n"
    }

    $crossTenantUrl = if ($entraPortal) { "$($entraPortal)#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/CrossTenantAccessSettings/menuId/CrossTenantAccessSettings" } else { $null }
    # A related tenant links to its page in Tenant governance > Related tenants; any other tenant to the cross-tenant access settings.
    $relatedTenantUrl = {
        param([string] $TenantId)
        if ($entraPortal -and $relatedTenantIds.Contains($TenantId)) { "$($entraPortal)#view/Microsoft_Entra_TenantManagement/TenantDetails.ReactView/id/$TenantId" } else { $crossTenantUrl }
    }
    $adminSignInUsers = {
        param([string] $TenantId)
        if ($adminSignIns.ContainsKey($TenantId)) { [int]$adminSignIns[$TenantId].inboundMonthlyTotalUsers } else { 0 }
    }

    if ($adminActiveIds.Count -gt 0) {
        $testResultMarkdown += "`n`n### 🌐 Related tenants with inbound admin app sign-ins (information only)`n`n"
        $testResultMarkdown += "Activity does not establish a GDAP or Tenant Governance relationship and does not affect the verdict. This includes allowlisted tenants.`n`n"
        $testResultMarkdown += "| Tenant | Admin app sign-ins (inbound) |`n| --- | --- |`n"
        foreach ($tenantId in @($adminActiveIds | Sort-Object -Property @{ Expression = { & $adminSignInUsers $_ }; Descending = $true }, @{ Expression = { $_ } })) {
            $testResultMarkdown += "| $(& $formatTenant $tenantId (& $lookupTenant $tenantId) (& $relatedTenantUrl $tenantId) -NoMarker) | $(& $formatAdminSignIns $tenantId) |`n"
        }
    }

    # For information: every service provider of the cross-tenant access settings, with the relationship found for it.
    # Neither the mark nor failure to read this table changes the verdict.
    if ($allServiceProviderIds.Count -gt 0) {
        $partnerIdList = @($directoryPartners | ForEach-Object { "$($_.partnerTenantId)" })
        $formatServiceProviderRelationship = {
            param([string] $TenantId)
            $found = @(
                if ($TenantId -in $governingIds) { '🏛️ Tenant Governance (governs this tenant)' }
                elseif ($TenantId -in $formerGoverningIds) { '🏛️ Former Tenant Governance (terminated)' }
                elseif ($governanceTenantIds.Contains($TenantId)) { '🏛️ Tenant Governance (does not govern this tenant)' }
                if ($TenantId -in $partnerIdList) { '🤝 CSP partner' }
                if ($TenantId -in $remoteGroupTenantIds) { '👥 Partner groups known here' }
                if ($assignmentsByTenant.ContainsKey($TenantId)) { '🛡️ Holds Microsoft Entra roles' }
            )
            $text = if ($found.Count -gt 0) { $found -join ' · ' } else { '_No relationship, groups or roles found: the mark may be left over from an ended relationship_' }
            if ($microsoftTenantIds.Contains($TenantId)) { $text = "Ⓜ️ Microsoft infrastructure · $text" }
            $text
        }
        $markOnlyCount = @($allServiceProviderIds | Where-Object { $_ -notin $accessTenantIds -and $_ -notin $partnerIdList -and -not $governanceTenantIds.Contains($_) }).Count
        $crossTenantText = if ($crossTenantUrl) { "[cross-tenant access settings]($crossTenantUrl)" } else { 'cross-tenant access settings' }
        $testResultMarkdown += "`n`n### ℹ️ Service providers in cross-tenant access settings`n`n"
        $testResultMarkdown += "For information only: the tenants marked as service providers in the $crossTenantText. The mark can remain after a relationship ends and is never used to determine the verdict, even when other partner metadata or role assignments are present."
        if ($markOnlyCount -gt 0) {
            $testResultMarkdown += " $(if ($markOnlyCount -eq 1) { '1 service provider has' } else { "$markOnlyCount service providers have" }) no relationship, groups or roles here: remove the partner configuration from the cross-tenant access settings if you no longer work with it."
        }
        $testResultMarkdown += "`n`n| Tenant | Relationship found | Admin app sign-ins (inbound) |`n| --- | --- | --- |`n"
        foreach ($tenantId in @($allServiceProviderIds | Sort-Object -Property @{ Expression = { & $adminSignInUsers $_ }; Descending = $true }, @{ Expression = { & $lookupTenant $_ } })) {
            $testResultMarkdown += "| $(& $formatTenant $tenantId (& $lookupTenant $tenantId) (& $relatedTenantUrl $tenantId) -NoMarker) | $(& $formatServiceProviderRelationship $tenantId) | $(& $formatAdminSignIns $tenantId) |`n"
        }
    }

    # A tenant that is not allowlisted fails the check.
    if ($notAllowlisted.Count -gt 0) {
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $false
    }
    # No tenant failed, but a source could not be read or a former governing tenant may still have access: a person
    # has to confirm the result.
    if ($sourceErrors.Count -gt 0 -or $formerGoverningToVerify.Count -gt 0) {
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
        return $true
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $true
}
