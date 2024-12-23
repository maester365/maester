<#
 .Synopsis
  Returns all the members of a role.

 .Description
  The role can be either active or eligible, defaults to getting members that are both active and eligible.

 .Example
  Get-MtRoleMember -Role GlobalAdministrator

  Returns all the Global administrators and includes both Eligible and Active members.

 .Example
  Get-MtRoleMember -Role GlobalAdministrator -MemberStatus Active

  Returns all the Global administrators that are currently active and excludes those that are eligible but not yet active.

 .Example
  Get-MtRoleMember -Role GlobalAdministrator -MemberStatus Active

  Returns all the Global administrators that are currently active and excludes those that are eligible but not yet active.

 .EXAMPLE
  Get-MtRoleMember -Role GlobalAdministrator,PrivilegedRoleAdministrator

  Returns all the Global administrators and Privileged Role administrators and includes both Eligible and Active members.

 .Example
  Get-MtRoleMember -RoleId "00000000-0000-0000-0000-000000000000"

  Returns all the members of the role with the specified RoleId and includes both Eligible and Active members.

  .Example
  Get-MtRoleMember -RoleId "00000000-0000-0000-0000-000000000000" -MemberStatus Active

  Returns all the currently active members of the role with the specified RoleId.

.LINK
    https://maester.dev/docs/commands/Get-MtRoleMember
#>
function Get-MtRoleMember {
  [CmdletBinding(DefaultParameterSetName = "RoleName")]
  param(
    # The name of the role to get members for.
    [Parameter(ParameterSetName = "RoleName", Position = 0, Mandatory = $true)]
    [ValidateSet('AIAdministrator', 'ApplicationAdministrator', 'ApplicationDeveloper', 'AttackPayloadAuthor', 'AttackSimulationAdministrator', 'AttributeAssignmentAdministrator', 'AttributeAssignmentReader', 'AttributeDefinitionAdministrator', 'AttributeDefinitionReader', 'AttributeLogAdministrator', 'AttributeLogReader', 'AuthenticationAdministrator', 'AuthenticationExtensibilityAdministrator', 'AuthenticationPolicyAdministrator', 'AzureADJoinedDeviceLocalAdministrator', 'AzureDevOpsAdministrator', 'AzureInformationProtectionAdministrator', 'B2CIEFKeysetAdministrator', 'B2CIEFPolicyAdministrator', 'BillingAdministrator', 'CloudAppSecurityAdministrator', 'CloudApplicationAdministrator', 'CloudDeviceAdministrator', 'ComplianceAdministrator', 'ComplianceDataAdministrator', 'ConditionalAccessAdministrator', 'CustomerLockBoxAccessApprover', 'DesktopAnalyticsAdministrator', 'DeviceJoin', 'DeviceManagers', 'DeviceUsers', 'DirectoryReaders', 'DirectorySynchronizationAccounts', 'DirectoryWriters', 'DomainNameAdministrator', 'Dynamics365Administrator', 'Dynamics365BusinessCentralAdministrator', 'EdgeAdministrator', 'ExchangeAdministrator', 'ExchangeRecipientAdministrator', 'ExtendedDirectoryUserAdministrator', 'ExternalIDUserFlowAdministrator', 'ExternalIDUserFlowAttributeAdministrator', 'ExternalIdentityProviderAdministrator', 'FabricAdministrator', 'GlobalAdministrator', 'GlobalReader', 'GlobalSecureAccessAdministrator', 'GroupsAdministrator', 'GuestInviter', 'GuestUser', 'HelpdeskAdministrator', 'HybridIdentityAdministrator', 'IdentityGovernanceAdministrator', 'InsightsAdministrator', 'InsightsAnalyst', 'InsightsBusinessLeader', 'IntuneAdministrator', 'KaizalaAdministrator', 'KnowledgeAdministrator', 'KnowledgeManager', 'LicenseAdministrator', 'LifecycleWorkflowsAdministrator', 'MessageCenterPrivacyReader', 'MessageCenterReader', 'Microsoft365MigrationAdministrator', 'MicrosoftHardwareWarrantyAdministrator', 'MicrosoftHardwareWarrantySpecialist', 'ModernCommerceAdministrator', 'NetworkAdministrator', 'OfficeAppsAdministrator', 'OnPremisesDirectorySyncAccount', 'OrganizationalBrandingAdministrator', 'OrganizationalMessagesApprover', 'OrganizationalMessagesWriter', 'PartnerTier1Support', 'PartnerTier2Support', 'PasswordAdministrator', 'PermissionsManagementAdministrator', 'PowerPlatformAdministrator', 'PrinterAdministrator', 'PrinterTechnician', 'PrivilegedAuthenticationAdministrator', 'PrivilegedRoleAdministrator', 'ReportsReader', 'RestrictedGuestUser', 'SearchAdministrator', 'SearchEditor', 'SecurityAdministrator', 'SecurityOperator', 'SecurityReader', 'ServiceSupportAdministrator', 'SharePointAdministrator', 'SharePointEmbeddedAdministrator', 'SkypeforBusinessAdministrator', 'TeamsAdministrator', 'TeamsCommunicationsAdministrator', 'TeamsCommunicationsSupportEngineer', 'TeamsCommunicationsSupportSpecialist', 'TeamsDevicesAdministrator', 'TeamsTelephonyAdministrator', 'TenantCreator', 'UsageSummaryReportsReader', 'User', 'UserAdministrator', 'UserExperienceSuccessManager', 'VirtualVisitsAdministrator', 'VivaGoalsAdministrator', 'VivaPulseAdministrator', 'Windows365Administrator', 'WindowsUpdateDeploymentAdministrator', 'WorkplaceDeviceJoin', 'YammerAdministrator')]
    [string[]]$Role,

    # The ID of the role to get members for.
    [Parameter(ParameterSetName = "RoleId", Position = 0, Mandatory = $true)]
    [guid[]]$RoleId,

    # The type of members to look for. Default is both Eligible and Active.
    [ValidateSet('Eligible', 'Active', 'EligibleAndActive')]
    [string]$MemberStatus
  )

  if (-not $MemberStatus -or $MemberStatus -eq "EligibleAndActive") {
    $Eligible = $Active = $true
  } elseif ($MemberStatus -eq "Eligible") {
    $Eligible = $true
  } elseif ($MemberStatus -eq "Active") {
    $Active = $true
  }

  if ($Role) {
    $RoleId = $Role | ForEach-Object { (Get-MtRoleInfo -RoleName $_) }
  }

  $scopes = (Get-MgContext).Scopes

  $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
  $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"

  foreach ($directoryRoleId in $RoleId) {
    $assignments = @()
    $groups = @()
    $types = @()
    if ($Active) {
      $types += @{active = "roleManagement/directory/roleAssignments" }
    }
    if ($Eligible -and ("RoleEligibilitySchedule.ReadWrite.Directory" -in $scopes -or "RoleManagement.ReadWrite.Directory" -in $scopes)) {
      $types += @{eligible = "roleManagement/directory/roleEligibilityScheduleRequests" }
    } elseif ($Eligible) {
      Write-Warning "Skipping eligible roles as required Graph permission 'RoleEligibilitySchedule.ReadWrite.Directory' was not present."
    }

    foreach ($type in $types) {
      if (-not $pim -and $type.Keys -eq "eligible") {
        Write-Verbose "Tenant not licensed for Entra ID PIM eligible assignments"
        continue
      }

      $dirAssignmentsSplat = @{
        ApiVersion      = "v1.0"
        RelativeUri     = "$($type.Values)"
        Filter          = "roleDefinitionId eq '$directoryRoleId'"
        QueryParameters = @{
          expand = "principal"
        }
      }

      if ($dirAssignmentsSplat.RelativeUri -eq "roleManagement/directory/roleEligibilityScheduleRequests") {
        # Exclude Revoked and other non-eligible states
        # See full list of states at https://learn.microsoft.com/en-us/graph/api/resources/request?view=graph-rest-1.0#properties
        $dirAssignmentsSplat.Filter += " and NOT(status eq 'Canceled' or status eq 'Denied' or status eq 'Failed' or status eq 'Revoked')"
      }

      $dirAssignments = Invoke-MtGraphRequest @dirAssignmentsSplat

      if ($dirAssignments.id.Count -eq 0) {
        Write-Verbose "No role assignments found"
        continue
      }
      $assignments += $dirAssignments.principal

      $groups = $assignments | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.group" }
      $groups | ForEach-Object {`
          #5/10/2024 - Entra ID Role Enabled Security Groups do not currently support nesting
          $assignments += Get-MtGroupMember -GroupId $_.id
      }
    }

    $assignments | Sort-Object id -Unique
  }
}