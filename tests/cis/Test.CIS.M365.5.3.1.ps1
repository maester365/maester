function Test-MtCisPrivilegedRolesActivatedNotAssigned {
    <#
    .SYNOPSIS
        Checks that privileged directory roles are activated through PIM instead of being permanently assigned.

    .DESCRIPTION
        Checks the active role assignments for privileged directory roles. Users and groups pass when the role is activated through Privileged Identity Management, and service principals pass when the assignment has an end date. Permanently assigned Global Administrator accounts are treated as possible emergency access accounts when they are configured in EmergencyAccessAccounts or, when none are configured, when they use the onmicrosoft.com domain. At most two are accepted, and activated assignments are not counted.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.3.1, L2)

    .EXAMPLE
        Test-MtCisPrivilegedRolesActivatedNotAssigned

        Returns true if no privileged role is permanently assigned apart from up to two emergency access accounts.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.3.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.3.1',
        Title = 'Ensure privileged role assignments are activated and not assigned',
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1098.003'),
        Control = ('cis-m365:5.3.1', 'nist-800-53-r5:AC-6(5)'),
        Service = 'Graph',
        License = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting privileged role definitions and assignments...'
    $globalAdminId = '62e90394-69f5-4237-9190-012177145e10'
    $privilegedRoles = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion beta -Filter 'isPrivileged eq true'
    $instances = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleAssignmentScheduleInstances' -QueryParameters @{ expand = 'principal' }

    $emergencyIds = @(Get-MtEmergencyAccessAccount | ForEach-Object { $_.ObjectId })
    $emergencyCandidates = 0
    $report = foreach ($instance in $instances) {
        $role = @($privilegedRoles) | Where-Object { $_.id -eq $instance.roleDefinitionId } | Select-Object -First 1
        if (-not $role) {
            continue
        }
        $principalType = $instance.principal.'@odata.type'
        $isEmergencyCandidate = $false
        if ($principalType -eq '#microsoft.graph.user' -or $principalType -eq '#microsoft.graph.group') {
            $compliant = $instance.assignmentType -eq 'Activated'
            # Only a permanent Global Administrator assignment to a user account can be an emergency access account.
            $looksLikeEmergencyAccount = if ($emergencyIds.Count -gt 0) { $emergencyIds -contains $instance.principalId } else { $instance.principal.userPrincipalName -match 'onmicrosoft\.com$' }
            if ($principalType -eq '#microsoft.graph.user' -and $role.id -eq $globalAdminId -and $instance.assignmentType -eq 'Assigned' -and $null -eq $instance.endDateTime -and $looksLikeEmergencyAccount) {
                $isEmergencyCandidate = $true
                $emergencyCandidates++
                $compliant = $true
            }
        } elseif ($principalType -eq '#microsoft.graph.servicePrincipal') {
            $compliant = $instance.assignmentType -eq 'Assigned' -and $null -ne $instance.endDateTime
        } else {
            $compliant = $false
        }
        [pscustomobject]@{
            Role = $role.displayName
            Principal = if ($instance.principal.userPrincipalName) { $instance.principal.userPrincipalName } else { $instance.principal.displayName }
            PrincipalType = ($principalType -replace '#microsoft.graph.', '')
            AssignmentType = $instance.assignmentType
            EmergencyCandidate = $isEmergencyCandidate
            Pass = $compliant
        }
    }
    $failed = @($report | Where-Object { -not $_.Pass })
    $testResult = $failed.Count -eq 0 -and $emergencyCandidates -le 2

    $passText = 'Privileged roles are activated through PIM and not permanently assigned.'
    $failText = if ($failed.Count -gt 0) { "$($failed.Count) privileged role assignment(s) are permanently assigned instead of activated." } else { "$emergencyCandidates accounts in the Global Administrator role look like emergency access accounts. At most 2 are expected." }

    $resultMd = "| Role | Principal | Type | Assignment | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in ($report | Sort-Object -Property Pass, Role | Select-Object -First 100)) {
        $resultMd += "| $($row.Role) | $($row.Principal) | $($row.PrincipalType) | $($row.AssignmentType)$(if ($row.EmergencyCandidate) { ' (emergency access candidate)' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }
    if (@($report).Count -gt 100) {
        $resultMd += "`nShowing 100 of $(@($report).Count) assignments."
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
