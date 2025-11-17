<#
 .Synopsis
  Returns all the members of a role.

 .Description
  The role can be either active or eligible, defaults to getting members that are both active and eligible.

  If the assigned member is a group, all members of that group will be returned.

 .Example
  Get-MtRoleMember -Role GlobalAdministrator

  Returns all the Global administrators and includes both Eligible and Active members.

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
  [CmdletBinding(DefaultParameterSetName = 'RoleName')]
  param(
    # The name of the role to get members for.
    [Parameter(ParameterSetName = 'RoleName', Position = 0, Mandatory = $true)]
    [ValidateSet('AIAdministrator', 'ApplicationAdministrator', 'ApplicationDeveloper', 'AttackPayloadAuthor', 'AttackSimulationAdministrator', 'AttributeAssignmentAdministrator', 'AttributeAssignmentReader', 'AttributeDefinitionAdministrator', 'AttributeDefinitionReader', 'AttributeLogAdministrator', 'AttributeLogReader', 'AttributeProvisioningAdministrator', 'AttributeProvisioningReader', 'AuthenticationAdministrator', 'AuthenticationExtensibilityAdministrator', 'AuthenticationPolicyAdministrator', 'AzureADJoinedDeviceLocalAdministrator', 'AzureDevOpsAdministrator', 'AzureInformationProtectionAdministrator', 'B2CIEFKeysetAdministrator', 'B2CIEFPolicyAdministrator', 'BillingAdministrator', 'CloudAppSecurityAdministrator', 'CloudApplicationAdministrator', 'CloudDeviceAdministrator', 'ComplianceAdministrator', 'ComplianceDataAdministrator', 'ConditionalAccessAdministrator', 'CustomerLockBoxAccessApprover', 'DesktopAnalyticsAdministrator', 'DeviceJoin', 'DeviceManagers', 'DeviceUsers', 'DirectoryReaders', 'DirectorySynchronizationAccounts', 'DirectoryWriters', 'DomainNameAdministrator', 'Dynamics365Administrator', 'Dynamics365BusinessCentralAdministrator', 'EdgeAdministrator', 'ExchangeAdministrator', 'ExchangeRecipientAdministrator', 'ExtendedDirectoryUserAdministrator', 'ExternalIDUserFlowAdministrator', 'ExternalIDUserFlowAttributeAdministrator', 'ExternalIdentityProviderAdministrator', 'FabricAdministrator', 'GlobalAdministrator', 'GlobalReader', 'GlobalSecureAccessAdministrator', 'GlobalSecureAccessLogReader', 'GroupsAdministrator', 'GuestInviter', 'GuestUser', 'HelpdeskAdministrator', 'HybridIdentityAdministrator', 'IdentityGovernanceAdministrator', 'InsightsAdministrator', 'InsightsAnalyst', 'InsightsBusinessLeader', 'IntuneAdministrator', 'IoTDeviceAdministrator', 'KaizalaAdministrator', 'KnowledgeAdministrator', 'KnowledgeManager', 'LicenseAdministrator', 'LifecycleWorkflowsAdministrator', 'MessageCenterPrivacyReader', 'MessageCenterReader', 'Microsoft365BackupAdministrator', 'Microsoft365MigrationAdministrator', 'MicrosoftHardwareWarrantyAdministrator', 'MicrosoftHardwareWarrantySpecialist', 'NetworkAdministrator', 'OfficeAppsAdministrator', 'OnPremisesDirectorySyncAccount', 'OrganizationalBrandingAdministrator', 'OrganizationalMessagesApprover', 'OrganizationalMessagesWriter', 'PartnerTier1Support', 'PartnerTier2Support', 'PasswordAdministrator', 'PeopleAdministrator', 'PermissionsManagementAdministrator', 'PowerPlatformAdministrator', 'PrinterAdministrator', 'PrinterTechnician', 'PrivilegedAuthenticationAdministrator', 'PrivilegedRoleAdministrator', 'ReportsReader', 'RestrictedGuestUser', 'SearchAdministrator', 'SearchEditor', 'SecurityAdministrator', 'SecurityOperator', 'SecurityReader', 'ServiceSupportAdministrator', 'SharePointAdministrator', 'SharePointEmbeddedAdministrator', 'SkypeforBusinessAdministrator', 'TeamsAdministrator', 'TeamsCommunicationsAdministrator', 'TeamsCommunicationsSupportEngineer', 'TeamsCommunicationsSupportSpecialist', 'TeamsDevicesAdministrator', 'TeamsTelephonyAdministrator', 'TenantCreator', 'UsageSummaryReportsReader', 'User', 'UserAdministrator', 'UserExperienceSuccessManager', 'VirtualVisitsAdministrator', 'VivaGoalsAdministrator', 'VivaPulseAdministrator', 'Windows365Administrator', 'WindowsUpdateDeploymentAdministrator', 'WorkplaceDeviceJoin', 'YammerAdministrator')]
    [string[]]$Role,

    # The ID of the role to get members for.
    [Parameter(ParameterSetName = 'RoleId', Position = 0, Mandatory = $true)]
    [guid[]]$RoleId,

    # The type of members to look for. Default is both Eligible and Active.
    [ValidateSet('Eligible', 'Active', 'EligibleAndActive')]
    [string]$MemberStatus
  )

  function Get-UsersInRole {
		[CmdletBinding()]
		param(
			[string]$Uri,
			[string]$RoleId,
			[string]$Filter,
			[ValidateSet('Eligible', 'Active')]
			[string]$RoleAssignmentType)

		if ($Filter) {
			$Filter = "roleDefinitionId eq '$RoleId' and $Filter"
		}
		else {
			$Filter = "roleDefinitionId eq '$RoleId'"
		}

		$params = @{
			ApiVersion      = "v1.0"
			RelativeUri     = $Uri
			Filter          = $Filter
			QueryParameters = @{
				expand = "principal"
			}
		}

		$dirAssignments = Invoke-MtGraphRequest @params -DisableCache

		$assignments = @()
		if ($dirAssignments.id.Count -eq 0) {
			Write-Verbose "No role assignments found"
			return $assignments
		}
		$assignments += @($dirAssignments.principal)

		$groups = $assignments | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.group" }
		$groups | ForEach-Object {
			#5/10/2024 - Entra ID Role Enabled Security Groups do not currently support nesting
			$assignments += Get-MtGroupMember -groupId $_.id
		}

		# Append the type of assignment
		$assignments | ForEach-Object {
			$_ | Add-Member -MemberType NoteProperty -Name "AssignmentType" -Value $RoleAssignmentType -Force
		}
		return $assignments
	}

  Write-Verbose "Getting members for RoleId: $RoleId, Role: $Role, MemberStatus: $MemberStatus"
  if (-not $MemberStatus -or $MemberStatus -eq 'EligibleAndActive') {
    $Eligible = $Active = $true
  } elseif ($MemberStatus -eq 'Eligible') {
    $Eligible = $true
  } elseif ($MemberStatus -eq 'Active') {
    $Active = $true
  }

  if ($Role) {
    $RoleId = $Role | ForEach-Object { (Get-MtRoleInfo -RoleName $_) }
  }

  $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
  $pim = $EntraIDPlan -eq 'P2' -or $EntraIDPlan -eq 'Governance'

	foreach ($directoryRoleId in $RoleId) {
		$assignments = @()
		if ($Active) {
			if ($pim) {
				$uri = 'roleManagement/directory/roleAssignmentScheduleInstances'
				# assignmentType eq 'Assigned' filters out eligible users that have temporarily activated the role
				$assignments += Get-UsersInRole -Uri $uri -RoleId $directoryRoleId -RoleAssignmentType Active -Filter "assignmentType eq 'Assigned'"
			}
			else {
				#Free or P1 tenant (PIM APIs cannot be called on non-P2 tenants)
				$uri = 'roleManagement/directory/roleAssignments'
				$assignments += Get-UsersInRole -Uri $uri -RoleId $directoryRoleId -RoleAssignmentType Active
			}
		}
		if ($Eligible) {
			$uri = 'roleManagement/directory/roleEligibilityScheduleInstances'
			$assignments += Get-UsersInRole -Uri $uri -RoleId $directoryRoleId -RoleAssignmentType Eligible
		}

		$assignments | Sort-Object id -Unique
	}
}
