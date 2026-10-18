function Get-MtCisConditionalAccessScopeProblem {
    <#
    .SYNOPSIS
        Returns why a Conditional Access policy does not cover the users and applications that a CIS check requires.

    .DESCRIPTION
        Reads who the policy includes and excludes, which applications it targets and which conditions narrow it.
        Only emergency access accounts from EmergencyAccessAccounts and the two directory synchronization roles may be excluded.
        A narrowing condition is reported unless the check is about that condition.

    .PARAMETER Policy
        A Conditional Access policy as returned by Get-MtConditionalAccessPolicy.

    .PARAMETER Users
        AllUsers requires All in includeUsers. AdministratorRoles also accepts a policy that includes every role from Get-MtCisAdministratorRole.

    .PARAMETER EmergencyAccessId
        Object IDs of the emergency access accounts and groups, as returned by Get-MtEmergencyAccessAccount.

    .PARAMETER Applications
        All, or the application IDs or user action that the check targets.

    .PARAMETER TargetedCondition
        Narrowing conditions that the check itself is about. These are not reported.

    .EXAMPLE
        Get-MtCisConditionalAccessScopeProblem -Policy $policy -EmergencyAccessId $emergency

        Returns no text when the policy covers all users and all cloud apps without unexpected exclusions.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [object] $Policy,

        [string[]] $EmergencyAccessId = @(),

        [ValidateSet('AllUsers', 'AdministratorRoles')]
        [string] $Users = 'AllUsers',

        [string[]] $Applications = @('All'),

        [ValidateSet('Platforms', 'Locations', 'DeviceFilter', 'ClientAppTypes', 'UserRiskLevels', 'SignInRiskLevels', 'InsiderRiskLevels', 'AuthenticationFlows')]
        [string[]] $TargetedCondition = @()
    )

    # The two roles that Test-MtCaExclusionForDirectorySyncAccount expects a policy to exclude.
    $syncRoleIds = @('d29b2b05-8046-44ba-8758-1e26182fcf32', 'a92aed5d-d78a-4d16-b381-09adb37eb3b0')
    $problems = [System.Collections.Generic.List[string]]::new()
    $conditions = $Policy.conditions
    $userScope = $conditions.users
    $appScope = $conditions.applications

    $includedUsers = @($userScope.includeUsers | Where-Object { $_ })
    if ($Users -eq 'AllUsers') {
        if ($includedUsers -notcontains 'All') { $problems.Add('not all users are included') }
    } elseif ($includedUsers -notcontains 'All') {
        $includedRoles = @($userScope.includeRoles | Where-Object { $_ })
        $missingRoles = @(Get-MtCisAdministratorRole | Where-Object { $includedRoles -notcontains $_.Id } | ForEach-Object { $_.Name })
        if ($missingRoles.Count -gt 0) { $problems.Add("administrative roles not included: $($missingRoles -join ', ')") }
    }

    foreach ($id in @($userScope.excludeUsers | Where-Object { $_ })) {
        if ($EmergencyAccessId -notcontains $id) { $problems.Add("excludes user $id") }
    }
    foreach ($id in @($userScope.excludeGroups | Where-Object { $_ })) {
        if ($EmergencyAccessId -notcontains $id) { $problems.Add("excludes group $id") }
    }
    foreach ($id in @($userScope.excludeRoles | Where-Object { $_ })) {
        if ($syncRoleIds -notcontains $id) { $problems.Add("excludes role $id") }
    }
    if (@($userScope.excludeGuestsOrExternalUsers.guestOrExternalUserTypes | Where-Object { $_ }).Count -gt 0) {
        $problems.Add('excludes guests or external users')
    }

    $includedApps = @($appScope.includeApplications | Where-Object { $_ })
    $includedActions = @($appScope.includeUserActions | Where-Object { $_ })
    $excludedApps = @($appScope.excludeApplications | Where-Object { $_ })
    if ($Applications -contains 'All') {
        if ($includedApps -notcontains 'All') { $problems.Add('not all cloud apps are included') }
        if ($excludedApps.Count -gt 0) { $problems.Add("excludes applications $($excludedApps -join ', ')") }
    } else {
        $covered = @($includedApps + $includedActions)
        $notTargeted = @($Applications | Where-Object { $covered -notcontains $_ })
        if ($notTargeted.Count -gt 0) { $problems.Add("does not target $($notTargeted -join ', ')") }
        $targetExcluded = @($Applications | Where-Object { $excludedApps -contains $_ })
        if ($targetExcluded.Count -gt 0) { $problems.Add("excludes $($targetExcluded -join ', ')") }
    }

    if ('Platforms' -notin $TargetedCondition -and $conditions.platforms) {
        $includedPlatforms = @($conditions.platforms.includePlatforms | Where-Object { $_ })
        $excludedPlatforms = @($conditions.platforms.excludePlatforms | Where-Object { $_ })
        if (($includedPlatforms.Count -gt 0 -and $includedPlatforms -notcontains 'all') -or $excludedPlatforms.Count -gt 0) {
            $problems.Add('platforms are limited')
        }
    }
    if ('Locations' -notin $TargetedCondition -and $conditions.locations) {
        $includedLocations = @($conditions.locations.includeLocations | Where-Object { $_ })
        $excludedLocations = @($conditions.locations.excludeLocations | Where-Object { $_ })
        if (($includedLocations.Count -gt 0 -and $includedLocations -notcontains 'All') -or $excludedLocations.Count -gt 0) {
            $problems.Add('locations are limited')
        }
    }
    if ('DeviceFilter' -notin $TargetedCondition -and $conditions.devices.deviceFilter.rule) {
        $problems.Add('a device filter applies')
    }
    if ('ClientAppTypes' -notin $TargetedCondition) {
        $clientAppTypes = @($conditions.clientAppTypes | Where-Object { $_ })
        if ($clientAppTypes.Count -gt 0 -and $clientAppTypes -notcontains 'all') { $problems.Add('client app types are limited') }
    }
    if ('UserRiskLevels' -notin $TargetedCondition -and @($conditions.userRiskLevels | Where-Object { $_ }).Count -gt 0) {
        $problems.Add('a user risk condition is set')
    }
    if ('SignInRiskLevels' -notin $TargetedCondition -and @($conditions.signInRiskLevels | Where-Object { $_ }).Count -gt 0) {
        $problems.Add('a sign-in risk condition is set')
    }
    if ('InsiderRiskLevels' -notin $TargetedCondition -and @($conditions.insiderRiskLevels | Where-Object { $_ }).Count -gt 0) {
        $problems.Add('an insider risk condition is set')
    }
    if ('AuthenticationFlows' -notin $TargetedCondition -and @($conditions.authenticationFlows.transferMethods | Where-Object { $_ }).Count -gt 0) {
        $problems.Add('authentication flows are limited')
    }

    return [string[]]$problems.ToArray()
}
