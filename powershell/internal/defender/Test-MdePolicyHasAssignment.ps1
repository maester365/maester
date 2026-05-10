function Test-MdePolicyHasAssignment {
    <#
    .SYNOPSIS
        Checks if a configuration policy is assigned to any groups or devices

    .DESCRIPTION
        Returns true if the policy has active assignments (not just exclusions).
        This helps ensure we only test policies that are actually deployed.

    .PARAMETER PolicyId
        The ID of the configuration policy to check

    .EXAMPLE
        Test-MdePolicyHasAssignment -PolicyId "abc-123"

        Returns $true if policy is assigned to groups or devices.

    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyId
    )

    try {
        $assignmentParams = @{
            RelativeUri = "deviceManagement/configurationPolicies/$PolicyId/assignments"
            ApiVersion  = 'beta'
            ErrorAction = 'Stop'
        }
        $assignments = @(Invoke-MtGraphRequest @assignmentParams)

        if ($assignments.Count -eq 0) {
            Write-Verbose "Policy $PolicyId has no assignments"
            return $false
        }

        # Look for inclusion assignments (not just exclusions)
        $validAssignments = @()
        foreach ($assignment in $assignments) {
            if ($assignment.target.'@odata.type' -in @(
                '#microsoft.graph.groupAssignmentTarget',
                '#microsoft.graph.allDevicesAssignmentTarget',
                '#microsoft.graph.allLicensedUsersAssignmentTarget'
            )) {
                $validAssignments += $assignment
            }
        }

        if ($validAssignments.Count -gt 0) {
            Write-Verbose "Policy $PolicyId has $($validAssignments.Count) valid assignments"
            return $true
        } else {
            Write-Verbose "Policy $PolicyId has only exclusion assignments"
            return $false
        }

    } catch {
        Write-Verbose "Error getting assignments for policy $PolicyId - $($_.Exception.Message). Treating as unassigned."
        return $false
    }
}
