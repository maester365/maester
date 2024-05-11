<#
.SYNOPSIS
    Checks if Global Admins is an acceptable number

.DESCRIPTION

    A minimum of two users and a maximum of eight users SHALL be provisioned with the Global Administrator role.

.EXAMPLE
    Test-MtCisaGlobalAdminCount

    Returns true if only 2 to 8 users are eligible to be global admins
#>

Function Test-MtCisaGlobalAdminCount {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"

    $role = Get-MtRole | Where-Object {`
        $_.displayName -eq "Global Administrator" }
    $assignments = @()

    $dirAssignmentsSplat = @{
        ApiVersion  = "v1.0"
        RelativeUri = "roleManagement/directory/roleAssignments"
        Filter      = "roleDefinitionId eq '$($role.ID)'"
    }
    $dirAssignments = Invoke-MtGraphRequest @dirAssignmentsSplat
    $dirAssignments | ForEach-Object {`
        $obj = $null
        $obj = Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri "directoryObjects/$($_.principalId)"
        $assignments += $obj
    }

    if ($pim) {
        $pimAssignmentsSplat = @{
            ApiVersion  = "v1.0"
            RelativeUri = "roleManagement/directory/roleEligibilityScheduleRequests"
            Filter      = "roleDefinitionId eq '$($role.ID)'"
        }
        $pimAssignments = Invoke-MtGraphRequest @pimAssignmentsSplat
        $pimAssignments | ForEach-Object {`
            $obj = $null
            $obj = Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri "directoryObjects/$($_.principalId)"
            $assignments += $obj
        }
    }

    $groups = $assignments | Where-Object {$_.'@odata.type' -eq "#microsoft.graph.group"}
    $groups | ForEach-Object {`
        #5/10/2024 - Entra ID Role Enabled Security Groups do not currently support nesting
        $assignments += Get-MtGroupMember -groupId $_.id
    }

    $globalAdministrators = $assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"
    }

    $testResult = $globalAdministrators.Count -ge 2 -and $globalAdministrators.Count -le 8

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has two or more and eight or fewer Global Administrators:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have the appropriate number of Global Administrators."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType Users -GraphObjects $globalAdministrators

    return $testResult
}