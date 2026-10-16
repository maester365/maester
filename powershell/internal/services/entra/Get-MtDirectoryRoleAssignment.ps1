function Get-MtDirectoryRoleAssignment {
    <#
    .SYNOPSIS
    Returns Entra directory role assignments, active and PIM-eligible.

    .DESCRIPTION
    Reads directory role assignments the same way for every caller, so the decision of when the PIM
    APIs can be used is made in one place.

    With Microsoft Entra ID P2 or Governance, active assignments come from
    roleAssignmentScheduleInstances, filtered to assignmentType 'Assigned' so an eligible role that is
    temporarily activated is not also returned as active, and eligible assignments come from
    roleEligibilityScheduleInstances. Without those licenses, or when the PIM APIs reject the tenant
    license even though subscribedSkus reports a P2 service plan, active assignments come from
    roleAssignments and eligible assignments are not read.

    Each assignment gets an AssignmentType property of Active or Eligible. The result has two
    properties: Assignments, and EligibleChecked, which is true when eligible assignments were read.

    .EXAMPLE
    $roleAssignments = Get-MtDirectoryRoleAssignment
    $roleAssignments.Assignments | Where-Object AssignmentType -eq 'Eligible'

    Returns the PIM-eligible assignments of every directory role.

    .EXAMPLE
    (Get-MtDirectoryRoleAssignment -RoleId '62e90394-69f5-4237-9190-012177145e10' -ExpandPrincipal).Assignments.principal

    Returns the principals that are assigned, or eligible for, the Global Administrator role.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Only return assignments of these role definitions. Assignments of every role are returned when omitted.
        [guid[]]$RoleId,

        # The type of assignments to return. Default is both Eligible and Active.
        [ValidateSet('Eligible', 'Active', 'EligibleAndActive')]
        [string]$MemberStatus = 'EligibleAndActive',

        # Expand the assigned principal on each assignment.
        [switch]$ExpandPrincipal,

        # Only return these properties of each assignment.
        [string[]]$Select,

        # Skip the Graph cache and read the assignments from Graph.
        [switch]$DisableCache
    )

    function Get-Assignment {
        param(
            [string]$Uri,
            [string[]]$Filter,
            [ValidateSet('Eligible', 'Active')]
            [string]$AssignmentType,
            [bool]$Expand,
            [string[]]$Property,
            [bool]$NoCache
        )

        $params = @{
            ApiVersion   = 'v1.0'
            RelativeUri  = $Uri
            DisableCache = $NoCache
        }
        if ($Property) { $params.Select = $Property }
        $Filter = @($Filter | Where-Object { $_ })
        if ($Filter) { $params.Filter = $Filter -join ' and ' }
        if ($Expand) { $params.QueryParameters = @{ expand = 'principal' } }

        foreach ($assignment in @(Invoke-MtGraphRequest @params)) {
            if ($null -eq $assignment) { continue }
            $assignment | Add-Member -MemberType NoteProperty -Name 'AssignmentType' -Value $AssignmentType -Force -PassThru
        }
    }

    $active = $MemberStatus -ne 'Eligible'
    $eligible = $MemberStatus -ne 'Active'
    # One request per role, or a single unfiltered request when no role is given
    $roleFilters = @(if ($RoleId) { $RoleId | ForEach-Object { "roleDefinitionId eq '$_'" } } else { '' })

    $pim = (Get-MtLicenseInformation -Product EntraID) -in @('P2', 'Governance')
    $assignments = [System.Collections.Generic.List[object]]::new()

    if ($pim) {
        try {
            foreach ($roleFilter in $roleFilters) {
                if ($active) {
                    # assignmentType eq 'Assigned' filters out eligible users that have temporarily activated the role
                    foreach ($assignment in Get-Assignment -Uri 'roleManagement/directory/roleAssignmentScheduleInstances' -Filter $roleFilter, "assignmentType eq 'Assigned'" -AssignmentType Active -Expand $ExpandPrincipal -Property $Select -NoCache $DisableCache) {
                        $assignments.Add($assignment)
                    }
                }
                if ($eligible) {
                    foreach ($assignment in Get-Assignment -Uri 'roleManagement/directory/roleEligibilityScheduleInstances' -Filter $roleFilter -AssignmentType Eligible -Expand $ExpandPrincipal -Property $Select -NoCache $DisableCache) {
                        $assignments.Add($assignment)
                    }
                }
            }
        } catch {
            # subscribedSkus can report a P2 service plan that the PIM APIs do not accept
            if ($active -and $_.ErrorDetails.Message -match 'AadPremiumLicenseRequired') {
                Write-Verbose 'PIM APIs require Entra ID P2 or Governance in this tenant. Using role assignments instead.'
                $pim = $false
                $assignments.Clear()
            } else {
                throw
            }
        }
    }

    if (-not $pim -and $active) {
        # Free or P1 tenant (PIM APIs cannot be called on non-P2 tenants)
        foreach ($roleFilter in $roleFilters) {
            foreach ($assignment in Get-Assignment -Uri 'roleManagement/directory/roleAssignments' -Filter $roleFilter -AssignmentType Active -Expand $ExpandPrincipal -Property $Select -NoCache $DisableCache) {
                $assignments.Add($assignment)
            }
        }
    }

    [pscustomobject]@{
        Assignments     = $assignments.ToArray()
        EligibleChecked = $eligible -and $pim
    }
}
