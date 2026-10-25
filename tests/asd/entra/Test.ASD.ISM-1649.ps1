function Test-MtAsdJustInTimeAdministration {
    <#
    .SYNOPSIS
    Checks that privileged directory roles have no permanent active assignments, so that administration is just-in-time.

    .DESCRIPTION
    ISM-1649 (Essential Eight, Restrict administrative privileges, Maturity Level Three) asks that just-in-time
    administration is used for the administration of systems and their resources.

    The check reads the active assignments of every directory role that Microsoft Entra marks as privileged.
    An assignment that has no end date and was not made through an activation is permanent, and fails the
    check; eligible assignments and time-bound active assignments made with Privileged Identity Management
    pass. The emergency access accounts named in the Maester configuration (EmergencyAccessAccounts) are
    left out, because a break glass account is meant to hold its role permanently.

    .EXAMPLE
    Test-MtAsdJustInTimeAdministration

    Returns true when no privileged role has a permanent active assignment outside the emergency access accounts.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1649
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1649',
        Title = 'Just-in-time administration is used for the administration of systems and their resources.',
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1098.003', 'T1078.004'),
        Control = ('essential-eight:ISM-1649', 'nist-800-53-r5:AC-2(7)', 'nist-800-53-r5:AC-6(5)'),
        Service = 'Graph',
        License = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $roles = @(Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -Select id, displayName, isPrivileged | Where-Object { $_.isPrivileged -eq $true })
    $roleName = @{}
    foreach ($role in $roles) { $roleName[$role.id] = $role.displayName }

    # Eligible assignments are read too: EligibleChecked tells whether the PIM APIs answered, which is what makes an assignment just-in-time.
    $read = Get-MtDirectoryRoleAssignment -ExpandPrincipal
    if (-not $read.EligibleChecked) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Privileged Identity Management is not available in this tenant, so every assignment is permanent. Just-in-time administration needs Microsoft Entra ID P2 or Microsoft Entra ID Governance.'
        return $null
    }
    $breakGlass = @(Get-MtEmergencyAccessAccount | ForEach-Object ObjectId)

    $permanent = @($read.Assignments | Where-Object {
            $_.AssignmentType -eq 'Active' -and
            $roleName.ContainsKey($_.roleDefinitionId) -and
            [string]::IsNullOrEmpty($_.endDateTime) -and
            $_.principalId -notin $breakGlass
        })
    $testResult = $permanent.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. No privileged directory role has a permanent active assignment. $($roles.Count) privileged roles were checked$(if ($breakGlass.Count -gt 0) { ", leaving out $($breakGlass.Count) emergency access account(s)" })."
    } else {
        $table = "| Role | Principal | Type | Scope |`n| --- | --- | --- | --- |`n"
        foreach ($assignment in ($permanent | Sort-Object { $roleName[$_.roleDefinitionId] }, { $_.principal.displayName })) {
            $principal = $assignment.principal
            $name = if ($principal.userPrincipalName) { $principal.userPrincipalName } elseif ($principal.displayName) { $principal.displayName } else { $assignment.principalId }
            $type = ([string]$principal.'@odata.type') -replace '^#microsoft\.graph\.', ''
            $table += "| $($roleName[$assignment.roleDefinitionId]) | $name | $type | $($assignment.directoryScopeId) |`n"
        }
        $testResultMarkdown = "$($permanent.Count) permanent active assignment(s) to privileged directory roles were found. Make them eligible in Privileged Identity Management so that administrators activate the role when they need it.`n`n$table"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
