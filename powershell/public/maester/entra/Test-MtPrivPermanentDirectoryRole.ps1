<#
 .Synopsis
  Checks if Permanent Assignments for Entra ID roles exists

 .Description
  GET /beta/roleManagement/directory/roleAssignments?$expand=principal

 .Example
  Test-MtPrivPermanentDirectoryRole -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ExternalUser"

.LINK
  https://maester.dev/docs/commands/Test-MtPrivPermanentDirectoryRole
#>
function Test-MtPrivPermanentDirectoryRole {
  [OutputType([bool])]
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('ControlPlane', 'ManagementPlane')]
    # Filter based on Enterprise Access Model Tiering. Can be 'ControlPlane' and/or 'ManagementPlane'.
    [string[]]$FilteredAccessLevel = $null,

    [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
    [ValidateSet('ExternalUser', 'HybridUser', 'ServicePrincipalClientSecret', 'ServicePrincipalObject', 'UserMailbox')]
    # Filter based on principal types. Accepted values are 'ExternalUser', 'HybridUser', 'ServicePrincipalClientSecret', 'ServicePrincipalObject' and/or 'UserMailbox'.
    [object[]]$FilterPrincipal
  )

  begin {
    $mgContext = Get-MgContext
    $tenantId = $mgContext.TenantId
  }

  process {
    try {
      $DirectAssignments = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleAssignments?$expand=principal' -ApiVersion beta
      $RoleDefinitions = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion beta

      if ($null -eq $DirectAssignments) {
        Write-Error 'No direct assignments found!'
      }

      if ($null -ne $FilteredAccessLevel) {
        $EamClassification = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json' | ConvertFrom-Json -Depth 10
        $FilteredClassification = ($EamClassification | Where-Object { $_.Classification.EAMTierLevelName -eq $FilteredAccessLevel }).RoleId
        $DirectAssignments = $DirectAssignments | Where-Object { $_.roleDefinitionId -in $FilteredClassification }
      }

      $PermDirRoleAssignments = switch ( $FilterPrincipal ) {
        ExternalUser {
          $DirectAssignments | Where-Object { $_.principal.userType -eq 'Guest' }
          $testDescription = "
  Take attention on B2B collaboration user with Entra ID directory role assignments on $($FilteredAccessLevel).
  Verify the affected external users, the user source (e.g., MSSP/partner or managing tenant) and if the privileged accounts pass your requirements for Conditional Access, Lifecycle Workflow and Identity Protection.
  Learn more about the best practices for privileges users:
    - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)"
        }
        HybridUser {
          $DirectAssignments | Where-Object { $null -ne $_.principal.onPremisesImmutableId -and $_.principal.OnPremisesSyncEnabled -eq $true }
          $testDescription = "
  It's recommended to use cloud-only accounts for privileges with $($FilteredAccessLevel) privileges to avoid attack paths from on-premises environment.
  Learn more about the best practices for privileges users:
    - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)
    - [Protecting Microsoft 365 from on-premises attacks](https://learn.microsoft.com/en-us/entra/architecture/protect-m365-from-on-premises-attacks#isolate-privileged-identities)
  "
        }
        ServicePrincipalClientSecret {
          # Looking for Service Principals with App Registrations (Application type from the same tenant)
          $PrivilegedAppIds = ($DirectAssignments | Where-Object { $_.principal.servicePrincipalType -eq 'Application' -and $_.principal.appOwnerOrganizationId -eq $tenantId }).principal.appId
          # Check if any Service Principal has a Client Secret
          $PrincipalWithSpSecret = ($DirectAssignments.principal | Where-Object { $_.principal.servicePrincipalType -eq 'Application' -and $_.principal.passwordCredentials } ).appId

          # Check if any Service Principal with App Registration has a Client secret
          if ($PrivilegedAppIds) {
            $PrincipalWithAppSecret = ($PrivilegedAppIds | ForEach-Object { Invoke-MtGraphRequest "applications(appId='$($_)')" -ApiVersion beta } | Where-Object { $_.passwordCredentials }).appId
          }
          # Return results filters Privileged Assignments with Client Secret
          $PrincipalWithSecrets = $PrincipalWithSpSecret + $PrincipalWithAppSecret
          if ($PrincipalWithSecrets) {
            $DirectAssignments | Where-Object { $_.Principal.AppId -in $PrincipalWithSecrets }
          }

          $testDescription = "
  Review your Service Principals with Client Secrets and $($FilteredAccessLevel) privileges.
  It's recommended to use certificates for Service Principals. Review if you can replace client secrets by certificates or use managed identities instead of a Service Principal.
  Learn more about the best practices for issuing certificates for Service Principals:
    - [Securing service principals in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/architecture/service-accounts-principal#service-principal-authentication)
    - [Best practices for all isolation architectures - Service Principal Credentials](https://learn.microsoft.com/en-us/entra/architecture/secure-best-practices#service-principals-credentials)
  "
        }
        ServicePrincipal {
          $DirectAssignments | Where-Object { $_.principal.servicePrincipalType -eq 'Application' }
          $testDescription = "
  Take attention on Service Principals with $($FilteredAccessLevel) privileges.
  In general, it's recommended to use managed identities over service principals (with client secrets or certificates) to avoid managing credentials and simplify lifecycle management.
  Learn more about the different type and best practices for workload identities:
    - [Types of Microsoft Entra service accounts](https://learn.microsoft.com/en-us/entra/architecture/secure-service-accounts#managed-identities)
    - [Managed identity best practice recommendations](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations)
  "
        }
        UserMailbox {
          $DirectAssignments | Where-Object { $_.principal.provisionedPlans.capabilityStatus -eq 'Enabled' -and $_.principal.provisionedPlans.service -contains 'exchange' }
          $testDescription = "
  Take attention on mail-enabled administrative accounts with $($FilteredAccessLevel) privileges.
  It's recommended to use mail forwarding to regular work account which allows to avoid direct mail access and phishing attacks on privileged user.
  Learn more about the best practices for securing privileged user accounts:
    - [Securing privileged access for hybrid and cloud deployments in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)
  "
        }
      }

      if ($PermDirRoleAssignments.Count -eq '0') {
        $result = $false
        $testResult = 'Well done!'
      } else {
        $result = $true

        $testResult = "These directory role assignments for $($FilterPrincipal) exists:`n`n"

        foreach ($PermDirRoleAssignment in $PermDirRoleAssignments | Sort-Object principalId, roleDefinitionId) {

          if ($PermDirRoleAssignment.directoryScopeId -eq '/') {
            $PermDirRoleAssignment.directoryScopeId = 'directory (tenant-wide)'
          }

          #region Portal Deep Link
          switch ($PermDirRoleAssignment.principal.'@odata.type') {
            '#microsoft.graph.user' { $PortalDeepLink = 'https://portal.azure.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/' }
            '#microsoft.graph.servicePrincipal' { $PortalDeepLink = 'https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/' }
            '#microsoft.graph.group' { $PortalDeepLink = 'https://portal.azure.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/' }
          }

          $Role = $RoleDefinitions | Where-Object { $_.templateId -eq $PermDirRoleAssignment.roleDefinitionId }
          $testResult += "  - [$($PermDirRoleAssignment.principal.displayName)]($($PortalDeepLink)$($PermDirRoleAssignment.principal.id)) with $($Role.displayName) on scope $($PermDirRoleAssignment.directoryScopeId)`n"
          Write-Verbose "Directory Role Assignment of $($FilterPrincipal) exists $($PermDirRoleAssignment.principal.displayName) is $($FilterPrincipal) as $($Role.displayName) on $($PermDirRoleAssignment.directoryScopeId)"
        }
      }
      Add-MtTestResultDetail -Description $testDescription -Result $testResult
      return $result
    } catch {
      Write-Error "An error occurred while testing Permanent Directory Role Assignments: $_"
      Add-MtTestResultDetail -Description 'An error occurred while testing Permanent Directory Role Assignments' -Result $_.Exception.Message
      return $false
    }
  } # end process block
} # end function
