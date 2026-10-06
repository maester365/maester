function Test-MtCisaPermanentRoleAssignment {
    <#
    .SYNOPSIS
    Checks for permanent active role assignments

    .DESCRIPTION
    Permanent active role assignments SHALL NOT be allowed for highly privileged roles.

    .EXAMPLE
    Test-MtCisaPermanentRoleAssignment

    Returns true if no roles have permanent active assignments

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPermanentRoleAssignment
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.7.4',
        Title = 'Permanent active role assignments SHALL NOT be allowed for highly privileged roles.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P2', 'MS.AAD', 'MS.AAD.7.4'),
        Service = 'Graph',
        CompatibleLicense = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Author = 'soulemike',
        Contributor = ('michaelmsonne', 'JeanPhilippeGeorge')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $roles = Get-MtRole -CisaHighlyPrivilegedRoles
    $roleAssignments = @()

    foreach ($role in $roles) {
        $principal = $null
        $roleAssignment = [PSCustomObject]@{
            role      = $role.displayName
            principal = $principal
        }
        $assignmentsSplat = @{
            ApiVersion      = "v1.0"
            RelativeUri     = "roleManagement/directory/roleAssignmentSchedules"
            Filter          = "roleDefinitionId eq '$($role.id)' and assignmentType eq 'Assigned'"
            QueryParameters = @{
                expand = "principal"
            }
        }
        $assignments = Invoke-MtGraphRequest @assignmentsSplat | Where-Object {`
                $_.scheduleInfo.expiration.type -eq "noExpiration" }

        $roleAssignment.principal = $assignments.principal

        $roleAssignments += $roleAssignment
    }

    $testResult = ($roleAssignments.principal | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no active assignments without expiration to privileged roles."
    } else {
        $testResultMarkdown = "Your tenant has active assignments without expiration to privileged roles.`n`n%TestResult%"
    }

    if (-not $testResult) {
        $result = "| Role | Principal Type | Display Name | Status |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($roleAssignment in ($roleAssignments | Where-Object { $_.principal })) {
            foreach ($principal in $roleAssignment.principal) {
                $result += "| $($roleAssignment.role) | $($principal.'@odata.type'.Split('.')[-1]) | $($principal.displayName ) | ❌ No Expiration |`n"
            }
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
