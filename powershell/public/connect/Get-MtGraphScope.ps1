function Get-MtGraphScope {
    <#
    .Synopsis
    Returns the list of Graph scopes required to run Maester.

    .Description
    Use this cmdlet to connect to Microsoft Graph using Connect-MgGraph.

    .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope)

    Connects to Microsoft Graph with the required scopes to run Maester.

    .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail)

    Connects to Microsoft Graph with the required scopes to run Maester and send email.

    .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope -SendTeamsMessage)

    Connects to Microsoft Graph with the required scopes to run Maester and send messages to a Teams Channel.

    .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope -PrivilegedScopes)

    Connects to Microsoft Graph with the required scopes to run Maester for all tests, including those requiring read write APIs.

    .Example
    Connect-MgGraph -Scopes (Get-MtGraphScope -IncludePreview)

    Connects to Microsoft Graph with the additional scopes required by preview tests.

    .Example
    Connect-MgGraph -Environment USGov -Scopes (Get-MtGraphScope -IncludePreview -Environment USGov)

    Connects to Microsoft Graph for US Government with the preview scopes that this cloud offers. Scopes of preview
    features that only the worldwide (Global) cloud offers, such as Tenant Governance, are left out: a national cloud
    rejects a sign-in that requests a permission it does not publish.

    .LINK
    https://maester.dev/docs/commands/Get-MtGraphScope
    #>

    [CmdletBinding()]
    param(
        # If specified, the cmdlet will include the scope to send email (Mail.Send).
        [Parameter(Mandatory = $false)]
        [switch] $SendMail,
        # If specified, the cmdlet will include the scope to send Teams Channel Messages (ChannelMessage.Send).
        [Parameter(Mandatory = $false)]
        [switch] $SendTeamsMessage,
        # If specified, the cmdlet will include the scope for read write endpoints.
        [Parameter(Mandatory = $false)]
        [switch] $Privileged,
        # If specified, the cmdlet will include scopes required by preview tests.
        [Parameter(Mandatory = $false)]
        [switch] $IncludePreview,
        # The Microsoft Graph cloud the scopes are requested in, as passed to Connect-Maester and Connect-MgGraph.
        # Preview scopes of features that only the worldwide cloud offers are included only for Global.
        [Parameter(Mandatory = $false)]
        [ValidateSet('China', 'Germany', 'Global', 'USGov', 'USGovDoD')]
        [string] $Environment = 'Global'
    )

    # Any changes made to these permission scopes should be reflected in the documentation.
    # /maester/website/docs/sections/permissions.md
    # - Use alphabetical sort order.
    # NOTE: We should only include read-only permissions in the default scopes.
    # Other permissions should be opted-in by the user with switches like -SendMail.

    # Default read-only scopes required for Maester.
    $scopes = @( #IMPORTANT: Read note above before adding any new scopes.
        'AccessReview.Read.All'
        'AuditLog.Read.All'
        'DeviceManagementApps.Read.All'
        'DeviceManagementConfiguration.Read.All'
        'DeviceManagementManagedDevices.Read.All'
        'DeviceManagementRBAC.Read.All'
        'DeviceManagementServiceConfig.Read.All'
        'Directory.Read.All'
        'DirectoryRecommendations.Read.All'
        'EntitlementManagement.Read.All'
        'IdentityRiskEvent.Read.All'
        'NetworkAccess.Read.All'
        'OnPremDirectorySynchronization.Read.All'
        'OrgSettings-AppsAndServices.Read.All'
        'OrgSettings-Forms.Read.All'
        'Policy.Read.All'
        'Policy.Read.ConditionalAccess'
        'Reports.Read.All'
        'ReportSettings.Read.All'
        'RoleEligibilitySchedule.Read.Directory'
        'RoleManagement.Read.All'
        'RoleManagementAlert.Read.Directory'
        'SecurityIdentitiesSensors.Read.All'
        'SecurityIdentitiesHealth.Read.All'
        'SharePointTenantSettings.Read.All'
        'ThreatHunting.Read.All'
        'UserAuthenticationMethod.Read.All'
    )

    # Any changes made to these permission scopes should be reflected in the documentation.
    # /maester/website/docs/sections/privilegedPermissions.md
    $privilegedScopes = @(
        'ReportSettings.ReadWrite.All'
    )

    $previewScopes = @(
        'AgentIdentity.Read.All'
        'AgentIdentityBlueprint.Read.All'
        'AgentIdentityBlueprintPrincipal.Read.All'
        'Application.Read.All'
        'IdentityRiskyUser.Read.All'
    )

    # Preview scopes of APIs that Microsoft Graph documents only for the worldwide (Global) service, which GCC also
    # uses. National clouds (US Government L4/L5, China) do not offer them, and Connect-MgGraph fails there when it
    # requests a permission the cloud does not publish:
    # - ConfigurationMonitoring.Read.All: Tenant Configuration Management (configurationMonitors, configurationDrifts)
    # - RemoteTenantGroups.Read.All: remoteTenantGroups
    # - TenantGovernance-*: governanceRelationships, relatedTenants (not in China; kept together with the feature)
    # - CrossTenantInformation.ReadBasic.All: available everywhere, but only used with the Tenant Governance checks
    $globalOnlyPreviewScopes = @(
        'ConfigurationMonitoring.Read.All'
        'CrossTenantInformation.ReadBasic.All'
        'RemoteTenantGroups.Read.All'
        'TenantGovernance-RelatedTenant.Read.All'
        'TenantGovernance-Relationship.Read.All'
    )

    if ($IncludePreview) {
        Write-Verbose -Message 'Adding preview scopes.'
        if ($Environment -eq 'Global') {
            $previewScopes = @($previewScopes + $globalOnlyPreviewScopes)
        } else {
            Write-Verbose -Message "Leaving out the preview scopes that are only available in the Global cloud ($Environment)."
        }
        $scopes = @($previewScopes + $scopes)
    }

    if ($Privileged) {
        Write-Verbose -Message "Adding Privileged scopes."
        $privilegedScopes | ForEach-Object { `
            $scopes += $_
        }
    }

    if ($SendMail) {
        Write-Verbose -Message "Adding SendMail scope."
        $scopes += 'Mail.Send'
    }

    if ($SendTeamsMessage) {
        Write-Verbose -Message "Adding SendTeamsMessage scope."
        $scopes += 'ChannelMessage.Send'
    }

    return $scopes
}
