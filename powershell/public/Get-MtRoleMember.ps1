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
    [guid]$roleId,
    [switch]$Eligible,
    [switch]$Active,
    [switch]$All
  )

  if($All){
    $Eligible = $Active = $true
  }
  elseif(-not $Eligible -and -not $Active){
    throw "Choose to return -Eligibile, -Active, or -All role members."
  }

  $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
  $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"

  $assignments = @()
  $groups = @()
  $types = @()
  if($Active){
    $types += @{active   = "roleManagement/directory/roleAssignments"}
  }
  if($Eligible){
    $types += @{eligible = "roleManagement/directory/roleEligibilityScheduleRequests"}
  }

  foreach($type in $types){
    if(-not $pim -and $type.Keys -eq "eligible"){
      Write-Verbose "Tenant not licensed for Entra ID PIM eligible assignments"
      continue
    }

    $dirAssignmentsSplat = @{
      ApiVersion      = "v1.0"
      RelativeUri     = "$($type.Values)"
      Filter          = "roleDefinitionId eq '$roleId'"
      QueryParameters = @{
        expand="principal"
      }
    }
    $dirAssignments = Invoke-MtGraphRequest @dirAssignmentsSplat

    if($dirAssignments.id.Count -eq 0){
      Write-Verbose "No role assignments found"
      continue
    }
    $assignments += $dirAssignments.principal

    $groups = $assignments | Where-Object {$_.'@odata.type' -eq "#microsoft.graph.group"}
    $groups | ForEach-Object {`
      #5/10/2024 - Entra ID Role Enabled Security Groups do not currently support nesting
      $assignments += Get-MtGroupMember -groupId $_.id
    }
  }

  return $assignments | Sort-Object id -Unique
}