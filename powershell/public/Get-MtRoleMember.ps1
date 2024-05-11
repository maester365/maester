<#
 .Synopsis
  Returns all the members of a role.

 .Description

 .Example
  Get-MtRoleMember
#>

Function Get-MtRoleMember {
  [CmdletBinding()]
  param(
    [Parameter(Position=0,mandatory=$true)]
    [guid]$roleId
  )

  $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
  $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"

  $assignments = @()
  $groups = @()
  $types = @(
    "roleManagement/directory/roleAssignments",
    "roleManagement/directory/roleEligibilityScheduleRequests"
  )

  foreach($type in $types){
    if(-not $pim -and $type -eq "roleManagement/directory/roleEligibilityScheduleRequests"){
      continue
    }

    $dirAssignmentsSplat = @{
      ApiVersion  = "v1.0"
      RelativeUri = "$type"
      Filter      = "roleDefinitionId eq '$roleId'"
    }
    $dirAssignments = Invoke-MtGraphRequest @dirAssignmentsSplat

    if($dirAssignments.id.Count -eq 0){
      #No role assignments found
      continue
    }

    $dirAssignments | ForEach-Object {`
        $obj = $null
        $obj = Invoke-MtGraphRequest -ApiVersion v1.0 -RelativeUri "directoryObjects/$($_.principalId)"
        $assignments += $obj
    }

    $groups = $assignments | Where-Object {$_.'@odata.type' -eq "#microsoft.graph.group"}
    $groups | ForEach-Object {`
        #5/10/2024 - Entra ID Role Enabled Security Groups do not currently support nesting
        $assignments += Get-MtGroupMember -groupId $_.id
    }
  }

  return $assignments | Sort-Object id -Unique
}