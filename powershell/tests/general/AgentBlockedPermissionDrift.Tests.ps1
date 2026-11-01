BeforeDiscovery {
    $snapshotPath = Join-Path $PSScriptRoot '../../internal/data/AgentBlockedPermissions.json'
    if (-not (Test-Path -LiteralPath $snapshotPath)) {
        throw "AgentBlockedPermissions.json not found at $snapshotPath. Run build/Update-MtAgentBlockedPermissions.ps1 first."
    }

    $snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
    $script:BlockedPermissions = $snapshot.Permissions

    # MT.1223's curated list from Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1.
    # These are the permissions the check looks for on agent identities.
    # If Microsoft blocks any of these for agents, the permission is dead weight in the check.
    $script:Mt1223Permissions = @(
        'AdministrativeUnit.ReadWrite.All'
        'Application.ReadUpdate.All'
        'DeviceManagementConfiguration.ReadWrite.All'
        'DeviceManagementRBAC.ReadWrite.All'
        'Policy.ReadWrite.ConditionalAccess'
        'PrivilegedAccess.ReadWrite.AzureADGroup'
        'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'
        'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup'
        'RoleAssignmentSchedule.ReadWrite.Directory'
        'RoleEligibilitySchedule.ReadWrite.Directory'
        'RoleManagementPolicy.ReadWrite.AzureADGroup'
        'RoleManagementPolicy.ReadWrite.Directory'
    )
}

Describe 'MT.1223 permission list vs. agent blocked permissions snapshot' {

    BeforeAll {
        $snapshotPath = Join-Path $PSScriptRoot '../../internal/data/AgentBlockedPermissions.json'
        $snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
        $script:BlockedPermissions = $snapshot.Permissions
    }

    It 'Snapshot file should have at least 50 permissions' {
        $script:BlockedPermissions.Count | Should -BeGreaterOrEqual 50
    }

    It '<permission> should not be blocked for Application in the snapshot' -ForEach @(
        $script:Mt1223Permissions | ForEach-Object { @{ Permission = $_ } }
    ) {
        $entry = $script:BlockedPermissions | Where-Object { $_.Permission -eq $permission }
        if ($null -eq $entry) {
            # Permission isn't in the blocked list at all, which means it's grantable. Pass.
            $true | Should -BeTrue
        } else {
            # If it IS in the blocked list with Application = true, it can't be granted to agents.
            # That means MT.1223 is checking a permission that can never fire.
            $entry.Application | Should -BeFalse -Because `
                "'$permission' is now blocked for Application by Microsoft (per AgentBlockedPermissions.json). It should be removed from MT.1223's curated list because agents can no longer hold it."
        }
    }
}
