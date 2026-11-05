function Add-MtZtaObjectFact {
    <#
    .SYNOPSIS
    Adds facts from the Zero Trust Assessment's tenant export to the objects on Maester's Affected objects page.

    .DESCRIPTION
    The assessment exports the tenant's applications, service principals, users, devices, directory roles, agent
    identities and Intune configuration policies into zt-export, next to its report, as pages of Graph JSON. This
    reads those pages and records what they say about each object with Add-MtAffectedObjectFact: an app's
    permissions, credentials and last sign-in, a user's roles, MFA registration and last sign-in, and so on.
    The facts appear on the objects that the run lists, whichever check named them.

    It runs in the pack's instance source, after the assessment and before a temporary output folder is deleted.
    Nothing is added when the export is not there (a report file copied on its own), when the
    ZeroTrustAssessment.ObjectFacts setting is false, or on a Maester version without Add-MtAffectedObjectFact.
    A problem reading the export is a warning, never a failed run.

    This is the only code in Maester that reads the export. When the assessment's tests become native Maester
    tests, delete this file, the Helpers entry in maester-pack.json and its call in Get-MtZtaInstance.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        # The report file, the assessment's output folder, or its zt-export folder.
        [Parameter(Mandatory)] [string] $ReportPath,

        # The assessment's report, read by Read-MtZtaReport, for its tenant id and when it ran.
        [Parameter(Mandatory)] $Report
    )

    if (-not (Get-Command -Name Add-MtAffectedObjectFact -ErrorAction Ignore)) { return }
    if (-not [bool](Get-MtSetting -Name 'ZeroTrustAssessment.ObjectFacts' -Default $true)) { return }
    # Facts are only kept while the run collects affected objects: skip reading the export otherwise.
    if (-not (Get-MtSession).IncludeAffectedObjects) { return }

    $folder = if (Test-Path -LiteralPath $ReportPath -PathType Container) { $ReportPath } else { Split-Path -Path $ReportPath -Parent }
    $root = $null
    if ($folder) {
        $root = @($folder, (Join-Path $folder 'zt-export')) | Where-Object {
            (Test-Path -LiteralPath (Join-Path $_ 'ServicePrincipal') -PathType Container) -or
            (Test-Path -LiteralPath (Join-Path $_ 'User') -PathType Container)
        } | Select-Object -First 1
    }
    if (-not $root) {
        Write-Verbose "No zt-export folder next to $ReportPath, so the Zero Trust Assessment adds no facts to the affected objects."
        return
    }

    try {
        $records = @(ConvertTo-MtZtaObjectFactRecord -ExportPath $root -Report $Report)
        if ($records.Count -eq 0) { return }
        $asOf = ConvertTo-MtZtaDate $Report.ExecutedAt
        $parameters = @{ Source = 'Zero Trust Assessment' }
        if ($asOf) { $parameters.AsOf = $asOf }
        $records | Add-MtAffectedObjectFact @parameters
        Write-Verbose "The Zero Trust Assessment export added facts about $($records.Count) object(s)."
    } catch {
        Write-Warning "The Zero Trust Assessment export could not be read, so its facts are not on the Affected objects page: $($_.Exception.Message)"
    }
}

function ConvertTo-MtZtaDate {
    <#
    .SYNOPSIS
    Returns a value of the export as a UTC date, or $null.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param([Parameter(Position = 0)] $Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) {
        # ConvertFrom-Json reads ISO dates already; an unspecified kind is UTC, as the export writes it.
        if ($Value.Kind -eq [System.DateTimeKind]::Unspecified) { return [datetime]::SpecifyKind($Value, [System.DateTimeKind]::Utc) }
        return $Value.ToUniversalTime()
    }
    if ($Value -is [datetimeoffset]) { return $Value.UtcDateTime }
    $parsed = [datetime]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
    if ([datetime]::TryParse([string]$Value, [cultureinfo]::InvariantCulture, $styles, [ref]$parsed)) { return $parsed }
    $null
}

function Read-MtZtaExportEntity {
    <#
    .SYNOPSIS
    Returns the objects of one entity of the assessment's export, read page by page.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)] [string] $ExportPath,
        [Parameter(Mandatory)] [string] $Name
    )

    $entityPath = Join-Path $ExportPath $Name
    if (-not (Test-Path -LiteralPath $entityPath -PathType Container)) { return }
    # Pages are <Name>-0.json, <Name>-1.json...; <Name>-model.json describes the table, not the data.
    foreach ($file in @(Get-ChildItem -LiteralPath $entityPath -File -Filter "$Name-*.json" | Where-Object { $_.BaseName -match '-\d+$' } | Sort-Object { [int]($_.BaseName -replace '^.*-', '') })) {
        $page = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8 | ConvertFrom-Json -Depth 30
        if ($null -eq $page) { continue }
        if ($page.PSObject.Properties['value']) { foreach ($item in @($page.value)) { if ($null -ne $item) { $item } } }
        else { $page }
    }
}

function ConvertTo-MtZtaObjectFactRecord {
    <#
    .SYNOPSIS
    Builds one record of facts per object in the assessment's export: System, Type, Id and Fact.

    .DESCRIPTION
    Tones follow Add-MtAffectedObjectFact: Risk for a path to tenant takeover or a privileged account without MFA,
    Warning for something to review (unused for 90 days, no owner or sponsor, a client secret, an unassigned
    policy), Good for a reassuring sign, Info for the rest.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $ExportPath,
        [Parameter(Mandatory)] $Report
    )

    $asOf = ConvertTo-MtZtaDate $Report.ExecutedAt
    if (-not $asOf) { $asOf = [datetime]::UtcNow }
    $tenantId = [string]$Report.TenantId
    $staleDays = 90
    $comparer = [System.StringComparer]::OrdinalIgnoreCase

    # The first-party Microsoft tenants that publish Microsoft's own apps.
    $microsoftTenants = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
            'f8cdef31-a31e-4b4a-93e4-5f571e91255a', '72f988bf-86f1-41af-91ab-2d7cd011db47', '33e01921-4d64-4f8c-a055-5bdaffd5e33d'
        ), $comparer)
    # Graph permissions with a direct or indirect path to Global Administrator: the Tier 0 list that MT.1050 and
    # MT.1051 use (https://github.com/emiliensocchi/azure-tiering).
    $tierZero = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
            'AdministrativeUnit.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All', 'Application.ReadWrite.All',
            'Application.ReadWrite.OwnedBy', 'DeviceManagementConfiguration.ReadWrite.All', 'DeviceManagementRBAC.ReadWrite.All',
            'Directory.ReadWrite.All', 'Domain.ReadWrite.All', 'EntitlementManagement.ReadWrite.All', 'Group.ReadWrite.All',
            'GroupMember.ReadWrite.All', 'Organization.ReadWrite.All', 'Policy.ReadWrite.AuthenticationMethod',
            'Policy.ReadWrite.ConditionalAccess', 'Policy.ReadWrite.PermissionGrant', 'PrivilegedAccess.ReadWrite.AzureADGroup',
            'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup', 'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup',
            'RoleAssignmentSchedule.ReadWrite.Directory', 'RoleEligibilitySchedule.ReadWrite.Directory',
            'RoleManagement.ReadWrite.Directory', 'RoleManagementPolicy.ReadWrite.AzureADGroup',
            'RoleManagementPolicy.ReadWrite.Directory', 'User-PasswordProfile.ReadWrite.All', 'User.DeleteRestore.All',
            'User.EnableDisableAccount.All', 'User.ReadWrite.All', 'UserAuthenticationMethod.ReadWrite.All'
        ), $comparer)
    $graphAppId = '00000003-0000-0000-c000-000000000000'

    $formatDate = { param([datetime]$Date) $Date.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture) }
    $daysBefore = { param([datetime]$Date) [int][math]::Floor(($asOf - $Date).TotalDays) }
    $describeWhen = {
        param([datetime]$Date)
        $days = & $daysBefore $Date
        if ($days -le 0) { return "$(& $formatDate $Date) (the day of the assessment)" }
        if ($days -eq 1) { return "$(& $formatDate $Date) (1 day before the assessment)" }
        "$(& $formatDate $Date) ($days days before the assessment)"
    }
    $join = {
        param([string[]]$Items, [int]$Max = 6)
        $all = @($Items | Where-Object { $_ })
        if ($all.Count -le $Max) { return $all -join ', ' }
        (($all | Select-Object -First $Max) -join ', ') + ", and $($all.Count - $Max) more"
    }
    # Key and Raw follow the shared fact keys (Add-MtAffectedObjectFact), so code can read a fact without its text.
    $newFact = {
        param($Name, $Value, $Tone = 'Info', [string] $Key, $Raw)
        $fact = [pscustomobject]@{ Name = $Name; Value = $Value; Tone = $Tone }
        if ($Key) {
            $fact | Add-Member -NotePropertyName Key -NotePropertyValue $Key
            # -NotePropertyValue keeps a list a list.
            $fact | Add-Member -NotePropertyName Raw -NotePropertyValue $Raw
        }
        $fact
    }
    $daysFact = {
        param($Date, [bool] $Stale)
        if ($Date) { & $newFact 'Last sign-in' (& $describeWhen $Date) $(if ($Stale) { 'Warning' } else { 'Info' }) 'signIn.daysSince' ([int](& $daysBefore $Date)) }
        else { & $newFact 'Last sign-in' 'None recorded' 'Warning' 'signIn.daysSince' $null }
    }
    $credentialFacts = {
        param($SecretList, $CertificateList)
        foreach ($kind in @(@{ Name = 'Client secrets'; Items = @($SecretList | Where-Object { $_ }) }, @{ Name = 'Certificates'; Items = @($CertificateList | Where-Object { $_ }) })) {
            if ($kind.Items.Count -eq 0) { continue }
            $ends = @($kind.Items | ForEach-Object { ConvertTo-MtZtaDate $_.endDateTime })
            $active = @($ends | Where-Object { $_ -and $_ -ge $asOf } | Sort-Object)
            $expired = @($ends | Where-Object { $_ -and $_ -lt $asOf }).Count
            $parts = [System.Collections.Generic.List[string]]::new()
            if ($active.Count -gt 0) { $parts.Add("$($active.Count) active, the next expires on $(& $formatDate $active[0])") }
            if ($expired -gt 0) { $parts.Add("$expired expired") }
            $tone = if ($kind.Name -eq 'Client secrets' -and $active.Count -gt 0) { 'Warning' }
            elseif ($active.Count -gt 0 -and ($active[0] - $asOf).TotalDays -le 30) { 'Warning' }
            else { 'Info' }
            # Keyed on the secrets when there are any, otherwise on the certificates, so an app has one app.credentialExpired.
            $key = if ($kind.Name -eq 'Client secrets' -or @($SecretList | Where-Object { $_ }).Count -eq 0) { 'app.credentialExpired' } else { $null }
            $anyExpired = @(@($SecretList) + @($CertificateList) | Where-Object { $_ } | ForEach-Object { ConvertTo-MtZtaDate $_.endDateTime } | Where-Object { $_ -and $_ -lt $asOf }).Count -gt 0
            & $newFact $kind.Name ($parts -join '; ') $tone $key $anyExpired
        }
    }

    # --- Directory roles: principal id -> 'Role (how)' ---------------------------------------------------------
    $roleDefinitions = [System.Collections.Generic.Dictionary[string, object]]::new($comparer)
    foreach ($definition in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'RoleDefinition')) {
        $roleDefinitions[[string]$definition.id] = $definition
        if ($definition.templateId) { $roleDefinitions[[string]$definition.templateId] = $definition }
    }
    $rolesByPrincipal = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new($comparer)
    $addRole = {
        param($PrincipalId, $RoleDefinitionId, [string]$How, $Scope)
        if (-not $PrincipalId -or -not $RoleDefinitionId) { return }
        $definition = $null
        $null = $roleDefinitions.TryGetValue([string]$RoleDefinitionId, [ref]$definition)
        $name = if ($definition) { [string]$definition.displayName } else { [string]$RoleDefinitionId }
        if ($Scope -and [string]$Scope -ne '/') { $How = "$How, scoped" }
        $list = $null
        if (-not $rolesByPrincipal.TryGetValue([string]$PrincipalId, [ref]$list)) {
            $list = [System.Collections.Generic.List[object]]::new()
            $rolesByPrincipal[[string]$PrincipalId] = $list
        }
        $label = "$name ($How)"
        if (-not ($list | Where-Object Label -EQ $label)) {
            $list.Add([pscustomobject]@{ Label = $label; Role = $name; Privileged = [bool]($definition -and $definition.isPrivileged); Permanent = $How -like 'permanent*' })
        }
    }
    # With PIM the schedule instances say how a role is held; without it only the assignments are exported.
    $activeInstances = @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'RoleAssignmentScheduleInstance')
    if ($activeInstances.Count -gt 0) {
        foreach ($instance in $activeInstances) {
            $how = if ([string]$instance.assignmentType -eq 'Activated') { 'activated' } else { 'permanent' }
            & $addRole $instance.principalId $instance.roleDefinitionId $how $instance.directoryScopeId
        }
        foreach ($member in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'RoleAssignmentScheduleInstanceGroup')) {
            & $addRole $member.id $member.roleDefinitionId 'permanent, through a group' $null
        }
    } else {
        foreach ($assignment in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'RoleAssignment')) {
            & $addRole $assignment.principalId $assignment.roleDefinitionId 'permanent' $assignment.directoryScopeId
        }
        foreach ($member in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'RoleAssignmentGroup')) {
            & $addRole $member.id $member.roleDefinitionId 'permanent, through a group' $null
        }
    }
    foreach ($instance in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'RoleEligibilityScheduleInstance')) {
        & $addRole $instance.principalId $instance.roleDefinitionId 'eligible' $instance.directoryScopeId
    }
    foreach ($member in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'RoleEligibilityScheduleInstanceGroup')) {
        & $addRole $member.id $member.roleDefinitionId 'eligible, through a group' $null
    }
    $roleFact = {
        param($PrincipalId, [switch] $User)
        $roles = $null
        if (-not $rolesByPrincipal.TryGetValue([string]$PrincipalId, [ref]$roles)) { return }
        $tone = if (@($roles | Where-Object { $_.Privileged -and $_.Permanent }).Count -gt 0) { 'Risk' } else { 'Info' }
        $text = & $join @($roles | Sort-Object { -not $_.Privileged }, Label | ForEach-Object Label)
        if ($User) {
            # user.privilegedRoles: the privileged roles the user holds in any way, permanent, activated or eligible.
            & $newFact 'Entra roles' $text $tone 'user.privilegedRoles' ([string[]]@($roles | Where-Object Privileged | ForEach-Object Role | Select-Object -Unique))
        } else {
            & $newFact 'Entra roles' $text $tone
        }
    }

    # --- Service principals: names of the resources and permissions they grant -------------------------------
    $servicePrincipals = @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'ServicePrincipal')
    $resourceName = [System.Collections.Generic.Dictionary[string, string]]::new($comparer)
    $appRoleName = [System.Collections.Generic.Dictionary[string, string]]::new($comparer)
    $servicePrincipalById = [System.Collections.Generic.Dictionary[string, object]]::new($comparer)
    $graphResourceIds = [System.Collections.Generic.HashSet[string]]::new($comparer)
    foreach ($sp in $servicePrincipals) {
        $resourceName[[string]$sp.id] = [string]$sp.displayName
        $servicePrincipalById[[string]$sp.id] = $sp
        if ([string]$sp.appId -eq $graphAppId) { $null = $graphResourceIds.Add([string]$sp.id) }
        foreach ($role in @($sp.appRoles)) {
            if ($role -and $role.id) { $appRoleName["$($sp.id)|$($role.id)"] = [string]$role.value }
        }
    }
    $lastSignIn = [System.Collections.Generic.Dictionary[string, object]]::new($comparer)
    $hasSignInActivity = $false
    foreach ($activity in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'ServicePrincipalSignIn')) {
        $hasSignInActivity = $true
        if ($activity.appId) { $lastSignIn[[string]$activity.appId] = ConvertTo-MtZtaDate $activity.lastSignInActivity.lastSignInDateTime }
    }

    # Facts about what an app can do, shared by its enterprise application and its app registration.
    $appFacts = {
        param($Sp)
        $isMicrosoft = $Sp.appOwnerOrganizationId -and $microsoftTenants.Contains([string]$Sp.appOwnerOrganizationId)

        $byResource = [ordered]@{}
        $risky = [System.Collections.Generic.List[string]]::new()
        foreach ($assignment in @($Sp.appRoleAssignments)) {
            if (-not $assignment) { continue }
            $name = $null
            if (-not $appRoleName.TryGetValue("$($assignment.resourceId)|$($assignment.appRoleId)", [ref]$name) -or -not $name) { continue }
            $resource = $null
            $null = $resourceName.TryGetValue([string]$assignment.resourceId, [ref]$resource)
            if (-not $resource) { $resource = 'Another app' }
            if (-not $byResource.Contains($resource)) { $byResource[$resource] = [System.Collections.Generic.List[string]]::new() }
            if (-not $byResource[$resource].Contains($name)) { $byResource[$resource].Add($name) }
            if ($graphResourceIds.Contains([string]$assignment.resourceId) -and $tierZero.Contains($name)) { $risky.Add($name) }
        }
        if ($byResource.Count -gt 0) {
            $text = (@($byResource.Keys | ForEach-Object { "$($_): $(& $join @($byResource[$_]) 8)" }) -join '; ')
            if ($risky.Count -gt 0) {
                $lead = if ($risky.Count -eq 1) { "$($risky[0]) has a path to Global Administrator" } else { "$(& $join @($risky) 4) have a path to Global Administrator" }
                & $newFact 'Application permissions' "$lead. $text" 'Risk' 'app.highPrivilegePermissions' ([string[]]@($risky))
            } else {
                & $newFact 'Application permissions' $text 'Info' 'app.highPrivilegePermissions' ([string[]]@())
            }
        }

        # Microsoft's own apps are consented for everyone when the tenant is created, so only other apps are listed.
        $tenantWide = @(if (-not $isMicrosoft) { $Sp.oauth2PermissionGrants | Where-Object { $_ -and [string]$_.consentType -eq 'AllPrincipals' } })
        if ($tenantWide.Count -gt 0) {
            $scopes = [System.Collections.Generic.List[string]]::new()
            $write = $false
            foreach ($grant in $tenantWide) {
                $resource = $null
                $null = $resourceName.TryGetValue([string]$grant.resourceId, [ref]$resource)
                $names = @(([string]$grant.scope) -split '\s+' | Where-Object { $_ -and $_ -notin 'openid', 'profile', 'offline_access', 'email' })
                if ($names | Where-Object { $_ -match '\.ReadWrite|\.Send$|FullControl|\.Manage' }) { $write = $true }
                if ($names.Count -gt 0) { $scopes.Add("$(if ($resource) { $resource } else { 'Another app' }): $(& $join $names 8)") }
            }
            if ($scopes.Count -gt 0) {
                & $newFact 'Consented for all users' ($scopes -join '; ') $(if ($write) { 'Warning' } else { 'Info' })
            }
        }
        $userGrants = @($Sp.oauth2PermissionGrants | Where-Object { $_ -and [string]$_.consentType -eq 'Principal' } | ForEach-Object principalId | Select-Object -Unique).Count
        if ($userGrants -gt 0) { & $newFact 'Consented by users' $(if ($userGrants -eq 1) { '1 user' } else { "$userGrants users" }) }

        if ($hasSignInActivity -and $Sp.appId) {
            $last = $null
            $null = $lastSignIn.TryGetValue([string]$Sp.appId, [ref]$last)
            if ($last) {
                & $daysFact $last ((& $daysBefore $last) -gt $staleDays -and -not $isMicrosoft)
            } elseif (-not $isMicrosoft) {
                & $daysFact $null $false
            }
        }
    }

    $records = [System.Collections.Generic.List[object]]::new()
    $add = {
        param([string]$System, [string]$Type, $Id, $Facts)
        $list = @($Facts | Where-Object { $_ })
        if ($Id -and $list.Count -gt 0) { $records.Add([pscustomobject]@{ System = $System; Type = $Type; Id = [string]$Id; Fact = $list }) }
    }

    # --- Enterprise applications (and agent identities, which are service principals) -------------------------
    $appFactsByAppId = [System.Collections.Generic.Dictionary[string, object[]]]::new($comparer)
    foreach ($sp in $servicePrincipals) {
        $facts = [System.Collections.Generic.List[object]]::new()
        $owner = [string]$sp.appOwnerOrganizationId
        $publisher = if ([string]$sp.servicePrincipalType -eq 'ManagedIdentity') { 'Managed identity' }
        elseif ($owner -and $owner -eq $tenantId) { 'This tenant' }
        elseif ($owner -and $microsoftTenants.Contains($owner)) { 'Microsoft' }
        elseif ($sp.publisherName) { "Another organization ($($sp.publisherName))" }
        elseif ($owner) { 'Another organization' }
        if ($publisher) { $facts.Add((& $newFact 'Publisher' $publisher)) }
        if ($sp.accountEnabled -eq $false) { $facts.Add((& $newFact 'Sign-in' 'Disabled')) }
        $shared = @(& $appFacts $sp)
        foreach ($fact in $shared) { $facts.Add($fact) }
        if ($sp.appId) { $appFactsByAppId[[string]$sp.appId] = $shared }
        $sso = [string]$sp.preferredSingleSignOnMode
        if ($sso -and $sso -ne 'notSupported') { $facts.Add((& $newFact 'Single sign-on' $sso.ToUpperInvariant().Replace('PASSWORD', 'Password-based'))) }
        foreach ($fact in @(& $credentialFacts $sp.passwordCredentials $sp.keyCredentials)) { $facts.Add($fact) }
        $role = & $roleFact $sp.id
        if ($role) { $facts.Add($role) }
        & $add 'EntraID' 'ServicePrincipal' $sp.id $facts
    }

    # --- App registrations: keyed by appId, as their portal link is ------------------------------------------
    $audience = @{
        AzureADMyOrg                       = 'This organization only'
        AzureADMultipleOrgs                = 'Any Microsoft Entra organization'
        AzureADandPersonalMicrosoftAccount = 'Any Microsoft Entra organization and personal Microsoft accounts'
        PersonalMicrosoftAccount           = 'Personal Microsoft accounts only'
    }
    foreach ($app in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'Application')) {
        $facts = [System.Collections.Generic.List[object]]::new()
        $who = [string]$app.signInAudience
        if ($who) { $facts.Add((& $newFact 'Who can sign in' $(if ($audience.ContainsKey($who)) { $audience[$who] } else { $who }))) }
        $owners = @($app.owners | Where-Object { $_ })
        $facts.Add((& $newFact 'Owners' $(if ($owners.Count -eq 0) { 'None' } else { [string]$owners.Count }) $(if ($owners.Count -eq 0) { 'Warning' } else { 'Info' }) 'app.ownerCount' ([int]$owners.Count)))
        foreach ($fact in @(& $credentialFacts $app.passwordCredentials $app.keyCredentials)) { $facts.Add($fact) }
        $shared = $null
        if ($app.appId -and $appFactsByAppId.TryGetValue([string]$app.appId, [ref]$shared)) { foreach ($fact in $shared) { $facts.Add($fact) } }
        & $add 'EntraID' 'AppRegistration' $app.appId $facts
    }

    # --- Users ----------------------------------------------------------------------------------------------
    $registration = [System.Collections.Generic.Dictionary[string, object]]::new($comparer)
    foreach ($detail in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'UserRegistrationDetails')) {
        if ($detail.id) { $registration[[string]$detail.id] = $detail }
    }
    foreach ($user in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'User')) {
        $facts = [System.Collections.Generic.List[object]]::new()
        $account = @(
            if ([string]$user.userType -eq 'Guest') { 'Guest' } else { 'Member' }
            if ($user.onPremisesSyncEnabled -eq $true) { 'synced from on-premises' }
            if ($user.accountEnabled -eq $false) { 'disabled' }
        ) -join ', '
        $facts.Add((& $newFact 'Account' $account))
        $role = & $roleFact $user.id -User
        if ($role) { $facts.Add($role) }

        $detail = $null
        if ($registration.TryGetValue([string]$user.id, [ref]$detail)) {
            $privileged = [bool]$detail.isAdmin -or ($role -and $role.Tone -eq 'Risk')
            if ($detail.isMfaRegistered -eq $true) {
                $methods = @($detail.methodsRegistered | Where-Object { $_ })
                $facts.Add((& $newFact 'MFA' $(if ($methods.Count -gt 0) { "Registered: $(& $join $methods)" } else { 'Registered' }) 'Good' 'user.mfaRegistered' $true))
            } elseif ($user.accountEnabled -ne $false) {
                $facts.Add((& $newFact 'MFA' 'Not registered' $(if ($privileged) { 'Risk' } else { 'Warning' }) 'user.mfaRegistered' $false))
            }
            if ($detail.isPasswordlessCapable -eq $true) { $facts.Add((& $newFact 'Passwordless' 'Can sign in without a password' 'Good' 'user.passwordless' $true)) }
            elseif ($detail.isPasswordlessCapable -eq $false) { $facts.Add((& $newFact 'Passwordless' 'Not set up' 'Info' 'user.passwordless' $false)) }
        }

        $activity = $user.signInActivity
        if ($activity) {
            $dates = @(
                ConvertTo-MtZtaDate $activity.lastSuccessfulSignInDateTime
                ConvertTo-MtZtaDate $activity.lastSignInDateTime
                ConvertTo-MtZtaDate $activity.lastNonInteractiveSignInDateTime
            ) | Where-Object { $_ } | Sort-Object -Descending
            if ($dates.Count -gt 0) {
                $facts.Add((& $daysFact $dates[0] ((& $daysBefore $dates[0]) -gt $staleDays -and $user.accountEnabled -ne $false)))
            } elseif ($user.accountEnabled -ne $false) {
                $facts.Add((& $daysFact $null $false))
            }
        }
        & $add 'EntraID' 'User' $user.id $facts
        # A check that names a user only by UPN ([upn]() links) gets a record keyed by the UPN when the run never read that user.
        if ($user.userPrincipalName) { & $add 'EntraID' 'User' $user.userPrincipalName $facts }
    }

    # --- Devices --------------------------------------------------------------------------------------------
    $joinType = @{ AzureAd = 'Microsoft Entra joined'; ServerAd = 'Microsoft Entra hybrid joined'; Workplace = 'Microsoft Entra registered' }
    foreach ($device in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'Device')) {
        $facts = [System.Collections.Generic.List[object]]::new()
        $os = (@($device.operatingSystem, $device.operatingSystemVersion) | Where-Object { $_ }) -join ' '
        if ($os) { $facts.Add((& $newFact 'Operating system' $os 'Info' 'device.os' ([string]$device.operatingSystem))) }
        $trust = [string]$device.trustType
        if ($trust) { $facts.Add((& $newFact 'Join type' $(if ($joinType.ContainsKey($trust)) { $joinType[$trust] } else { $trust }) 'Info' 'device.joinType' $trust)) }
        # A registered (personal) device is often unmanaged by design; a joined one should be managed.
        $joined = $trust -in 'AzureAd', 'ServerAd'
        $managed = $device.isManaged -eq $true
        $facts.Add((& $newFact 'Management' $(if ($managed) { 'Managed' } else { 'Not managed' }) $(if (-not $managed -and $joined) { 'Warning' } else { 'Info' }) 'device.managed' $managed))
        if ($managed -or $null -ne $device.isCompliant) {
            $compliant = $device.isCompliant -eq $true
            $facts.Add((& $newFact 'Compliance' $(if ($compliant) { 'Compliant' } else { 'Not compliant' }) $(if ($compliant) { 'Good' } else { 'Warning' }) 'device.compliant' $compliant))
        }
        if ($device.accountEnabled -eq $false) { $facts.Add((& $newFact 'Status' 'Disabled')) }
        $last = ConvertTo-MtZtaDate $device.approximateLastSignInDateTime
        if ($last) {
            $facts.Add((& $daysFact $last ((& $daysBefore $last) -gt $staleDays -and $device.accountEnabled -ne $false)))
        }
        & $add 'EntraID' 'Device' $device.id $facts
    }

    # --- Agent identities and their blueprints -----------------------------------------------------------------
    $blueprints = @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'AgentIdentityBlueprint')
    $blueprintName = [System.Collections.Generic.Dictionary[string, string]]::new($comparer)
    foreach ($blueprint in $blueprints) {
        if ($blueprint.appId) { $blueprintName[[string]$blueprint.appId] = [string]$blueprint.displayName }
        if ($blueprint.id) { $blueprintName[[string]$blueprint.id] = [string]$blueprint.displayName }
    }
    $agentsPerBlueprint = @{}
    foreach ($agent in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'AgentIdentity')) {
        $facts = [System.Collections.Generic.List[object]]::new()
        $name = $null
        if ($agent.agentIdentityBlueprintId) {
            $key = [string]$agent.agentIdentityBlueprintId
            $agentsPerBlueprint[$key] = 1 + [int]$agentsPerBlueprint[$key]
            if ($blueprintName.TryGetValue($key, [ref]$name) -and $name) { $facts.Add((& $newFact 'Blueprint' $name)) }
        }
        $sponsors = @($agent.sponsors | Where-Object { $_ }).Count
        $facts.Add((& $newFact 'Sponsors' $(if ($sponsors -eq 0) { 'None' } else { [string]$sponsors }) $(if ($sponsors -eq 0) { 'Warning' } else { 'Info' })))
        if ($agent.accountEnabled -eq $false) { $facts.Add((& $newFact 'Sign-in' 'Disabled')) }
        $sp = $null
        if ($servicePrincipalById.TryGetValue([string]$agent.id, [ref]$sp)) { foreach ($fact in @(& $appFacts $sp)) { $facts.Add($fact) } }
        $role = & $roleFact $agent.id
        if ($role) { $facts.Add($role) }
        & $add 'EntraID' 'AgentIdentity' $agent.id $facts
    }
    foreach ($blueprint in $blueprints) {
        $facts = [System.Collections.Generic.List[object]]::new()
        $owners = @($blueprint.owners | Where-Object { $_ }).Count
        $facts.Add((& $newFact 'Owners' $(if ($owners -eq 0) { 'None' } else { [string]$owners }) $(if ($owners -eq 0) { 'Warning' } else { 'Info' }) 'app.ownerCount' ([int]$owners)))
        $sponsors = @($blueprint.sponsors | Where-Object { $_ }).Count
        $facts.Add((& $newFact 'Sponsors' $(if ($sponsors -eq 0) { 'None' } else { [string]$sponsors }) $(if ($sponsors -eq 0) { 'Warning' } else { 'Info' })))
        $count = [int]$agentsPerBlueprint[[string]$blueprint.appId]
        $facts.Add((& $newFact 'Agent identities' $(if ($count -eq 1) { '1' } else { [string]$count })))
        foreach ($fact in @(& $credentialFacts $blueprint.passwordCredentials $blueprint.keyCredentials)) { $facts.Add($fact) }
        & $add 'EntraID' 'AgentIdentityBlueprint' $blueprint.appId $facts
    }

    foreach ($principal in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'AgentIdentityBlueprintPrincipal')) {
        $facts = [System.Collections.Generic.List[object]]::new()
        $name = $null
        if ($principal.appId -and $blueprintName.TryGetValue([string]$principal.appId, [ref]$name) -and $name) { $facts.Add((& $newFact 'Blueprint' $name)) }
        if ($principal.accountEnabled -eq $false) { $facts.Add((& $newFact 'Sign-in' 'Disabled')) }
        $sp = $null
        if ($servicePrincipalById.TryGetValue([string]$principal.id, [ref]$sp)) { foreach ($fact in @(& $appFacts $sp)) { $facts.Add($fact) } }
        $role = & $roleFact $principal.id
        if ($role) { $facts.Add($role) }
        & $add 'EntraID' 'AgentIdentityBlueprintPrincipal' $principal.id $facts
    }

    # --- Intune configuration policies ---------------------------------------------------------------------------
    foreach ($policy in @(Read-MtZtaExportEntity -ExportPath $ExportPath -Name 'ConfigurationPolicy')) {
        $facts = [System.Collections.Generic.List[object]]::new()
        $assignments = @($policy.assignments | Where-Object { $_ }).Count
        $facts.Add((& $newFact 'Assignments' $(if ($assignments -eq 0) { 'Not assigned' } else { [string]$assignments }) $(if ($assignments -eq 0) { 'Warning' } else { 'Info' })))
        $platform = (@($policy.platforms, $(if ($policy.technologies) { "($($policy.technologies -replace ',', ', '))" })) | Where-Object { $_ }) -join ' '
        if ($platform) { $facts.Add((& $newFact 'Platform' $platform)) }
        if ($null -ne $policy.settingCount) { $facts.Add((& $newFact 'Settings' ([string]$policy.settingCount))) }
        $modified = ConvertTo-MtZtaDate $policy.lastModifiedDateTime
        if ($modified) { $facts.Add((& $newFact 'Last changed' (& $describeWhen $modified))) }
        & $add 'Intune' 'ConfigurationPolicy' $policy.id $facts
    }

    $records.ToArray()
}
