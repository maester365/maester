Function Test-MtPrivPermanentDirectoryRoles {
  [OutputType([object])]
  <#
 .Synopsis
  Checks if Permanent Assignments for Entra ID roles exists

 .Description
  GET /beta/roleManagement/directory/roleAssignments?$expand=principal

 .Example
  Test-MtPrivPermanentDirectoryRoles -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ExternalUser"
  #>

  param (

    # The Enterprise Access Model level which should be considered for the filter
    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("ControlPlane", "ManagementPlane")]
    [string[]]$FilteredAccessLevel = $null,

    # The Enterprise Access Model level which should be considered for the filter
    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [object[]]$FilteredBreakGlassObjectIds = $null,

    # The Enterprise Access Model level which should be considered for the filter
    [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
    [ValidateSet("ExternalUser", "HybridUser", "ServicePrincipalClientSecret", "ServicePrincipalObject", "UserMailbox")]
    [object[]]$FilterPrincipal
  )

  $DirectAssignments = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleAssignments?$expand=principal' -ApiVersion beta
  $RoleDefinitions = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion beta

  if ($null -eq $DirectAssignments) {
    Write-Error "No direct assignments found!"
  }

  if ($null -ne $FilteredAccessLevel) {
    $EamClassification = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json' | ConvertFrom-Json -Depth 10
    $FilteredClassification = ($EamClassification | Where-Object { $_.Classification.EAMTierLevelName -eq $FilteredAccessLevel }).RoleId
    $DirectAssignments = $DirectAssignments | Where-Object { $_.roleDefinitionId -in $FilteredClassification }
  }

  $PermDirRoleAssignments = switch ( $FilterPrincipal ) {
    ExternalUser {
      $DirectAssignments | Where-Object { $_.principal.userType -eq "Guest" }
      $testDescription = "
      Take attention on B2B collaboration user (outside of MSSP/partner relationsship) with $($FilteredAccessLevel) privileges.
      Ensure the external users are from authorized external tenants and passes your requirements for Conditional Access, Lifecycle Workflow and Identity Protection like your internal users.
      Learn more about the best practices for privileges users:
       - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)"
    }
    HybridUser {
      $DirectAssignments | Where-Object { $null -ne $_.principal.onPremisesImmutableId }
      $testDescription = "
      It's recommended to use cloud-only accounts for privileges with $($FilteredAccessLevel) privileges to avoid attack paths from on-premises environment.
      Learn more about the best practices for privileges users:
       - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)
       - [Protecting Microsoft 365 from on-premises attacks](https://learn.microsoft.com/en-us/entra/architecture/protect-m365-from-on-premises-attacks#isolate-privileged-identities)
      "
    }
    ServicePrincipalClientSecret {
      $DirectAssignments | Where-Object { $_.principal.keyCredentials -eq "Symmetric" }
      $testDescription = "
      Take attention on Service Principals with Client Secrets and $($FilteredAccessLevel) privileges.
      It's recommended to use at least certificates for Service Principals with high privileges. Review if you can use managed identities instead of a Service Principal."
    }
    ServicePrincipal {
      $DirectAssignments | Where-Object { $_.principal.servicePrincipalType -eq "Application" }
      $testDescription = "
      Take attention on Service Principals with $($FilteredAccessLevel) privileges.
      It's recommended to use managed identities for Service Principals with high privileges."
    }
    UserMailbox {
      $DirectAssignments | Where-Object { $_.principal.provisionedPlans -contains "exchange" }
      $testDescription = "
      Take attention of mail-enabled administrative accounts with $($FilteredAccessLevel) privileges.
      It's recommended to use mail forwarding to regular work account and avoiding direct mail access from the privileged user."
    }
  }

  if ($PermDirRoleAssignments.Count -eq "0") {
    $result = $true
  }  else {
    $result = $false

    if ($PermDirRoleAssignment.directoryScopeId -eq "/") {
      $PermDirRoleAssignment.directoryScopeId = "Directory-level"
    }

    $testResult = "These directory role assignments for $($FilterPrincipal) exists:`n`n"
    foreach ($PermDirRoleAssignment in $PermDirRoleAssignments) {
      $Role = $RoleDefinitions | where-object { $_.templateId -eq $PermDirRoleAssignment.roleDefinitionId }
      $testResult += "  - $($PermDirRoleAssignment.principal.displayName) is $($FilterPrincipal) as $($Role.displayName) on $($PermDirRoleAssignment.directoryScopeId)"
      Write-Verbose "Directory Role Assignment of $($FilterPrincipal) exists $($PermDirRoleAssignment.principal.displayName) is $($FilterPrincipal) as $($Role.displayName) on $($PermDirRoleAssignment.directoryScopeId)"
    }
    Add-MtTestResultDetail -Description $testDescription -Result $testResult
  }
  return $result
}


