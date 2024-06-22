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
    [Parameter(ParameterSetName="All",Position=0,Mandatory=$true)]
    [Parameter(ParameterSetName="Active",Position=0,Mandatory=$true)]
    [Parameter(ParameterSetName="Eligible",Position=0,Mandatory=$true)]
    [guid]$roleId,
    [Parameter(ParameterSetName="Eligible",Mandatory=$true)]
    [switch]$Eligible,
    [Parameter(ParameterSetName="Active",Mandatory=$true)]
    [switch]$Active,
    [Parameter(ParameterSetName="All",Mandatory=$true)]
    [switch]$All
  )

  if($All){
    $Eligible = $Active = $true
  }

  $scopes = (Get-MgContext).Scopes

  $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
  $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"

  $assignments = @()
  $groups = @()
  $types = @()
  if($Active){
    $types += @{active   = "roleManagement/directory/roleAssignments"}
  }
  if($Eligible -and "RoleEligibilitySchedule.ReadWrite.Directory" -in $scopes){
    $types += @{eligible = "roleManagement/directory/roleEligibilityScheduleRequests"}
  }elseif($Eligible){
    Write-Warning "Skipping eligible roles as required Graph permission 'RoleEligibilitySchedule.ReadWrite.Directory' was not present."
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

    if($dirAssignmentsSplat.RelativeUri -eq "roleManagement/directory/roleEligibilityScheduleRequests"){
      # Exclude Revoked and other non-eligible states
      # See full list of states at https://learn.microsoft.com/en-us/graph/api/resources/request?view=graph-rest-1.0#properties
      $dirAssignmentsSplat.Filter += " and NOT(status eq 'Canceled' or status eq 'Denied' or status eq 'Failed' or status eq 'Revoked')"
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