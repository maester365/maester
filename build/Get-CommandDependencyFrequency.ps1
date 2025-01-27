function Get-CommandDependencyFrequency {
    <#
    .SYNOPSIS
    Get command dependencies in the public PowerShell scripts.

    .DESCRIPTION
    This function reads all the public PowerShell scripts and counts the number of times each command is used in them.
    It returns a list of all used commands, the number of times they are used, the module the command is from, and the
    files each command is used in.

    .PARAMETER Path
    The path to the directory containing the PowerShell scripts to inspect. Defaults to '/powershell/public'.

    .PARAMETER InternalFunctionsPath
    The path to the internal functions for this project. Defaults to '/powershell/internal'.

    .PARAMETER ExcludeBuiltIn
    Exclude built-in PowerShell commands from the results.

    .PARAMETER ExcludeUnknown
    Exclude unknown commands and private functions from the results.

    .EXAMPLE
    Get-CommandDependencyFrequency

    Gets all command dependencies in the public PowerShell scripts with their usage and source module.

    .EXAMPLE
    Get-CommandDependencyFrequency -ExcludeBuiltIn

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding built-in PowerShell commands.

    .EXAMPLE
    Get-CommandDependencyFrequency -ExcludeUnknown

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding unknown commands and private functions.

    .EXAMPLE
    $CommandDependencies = Get-CommandDependencyFrequency -ExcludeBuiltIn | Sort-Object -Property Module,Command
    $CommandDependencies | Select-Object Module -Unique
    $CommandDependencies | Group-Object -Property Module -NoElement | Format-Table -AutoSize

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding built-in PowerShell commands.
    Then returns a list of dependency unique module names.
    Then returns a table showing each dependent module and the number of commands used from it.

    .NOTES
    To Do:
    - Track known, internal private functions so they can be reported accurately in the results. (In Progress)
    - Possible improvements or automation for tracking Exchange Online remote commands.
    #>

    [CmdletBinding()]
    param (
        # Path to inspect PowerShell scripts in.
        [Parameter(Position = 0)]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [string]
        $Path = (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'powershell/public'),

        # Path to the internal functions for this project.
        [Parameter()]
        [ValidateScript({ if ( (Test-Path -Path $_ -PathType Container) -or ([string]::IsNullOrEmpty($_)) ) { $true } })]
        [string]
        $InternalFunctionsPath = (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'powershell/internal'),

        # Exclude built-in PowerShell commands.
        [Parameter()]
        [switch]
        $ExcludeBuiltIn,

        # Exclude unknown commands.
        [Parameter()]
        [switch]
        $ExcludeUnknown
    )

    # region FilterResults
    $FilterConditions = '( $_ )'
    if ($ExcludeBuiltIn.IsPresent) {
        $FilterConditions += ' -and ( $_.Module -notin @("Pester", "PowerShellGet") -and $_.Module -notlike "Microsoft.PowerShell*" -and $_.Module -notlike "DnsClient*")'
    }
    if ($ExcludeUnknown.IsPresent) {
        $FilterConditions += ' -and ( $_.Module -ne "Unknown Module or Private Command" )'
    }
    $Filter = [scriptblock]::Create($FilterConditions)
    #endregion FilterResults

    #region GetInternalFunctions
    if ($InternalFunctionsPath) {
        [string[]]$InternalFunctions = Get-ChildItem -Path $InternalFunctionsPath -File *.ps1 |
            Select-Object -ExpandProperty BaseName
    }
    #endregion GetInternalFunctions

    #region EXORemoteModuleCommands
    # $EXORemoteModuleCommands = (Get-Command -ListImported | Where-Object { $_.Source -like 'tmpEXO_*' }).Name
    # [string[]]$List = "'$($EXORemoteCommandList -join "',`n'")'"
    $EXORemoteModuleCommands = @(
        'Add-DistributionGroupMember',
        'Add-MailboxFolderPermission',
        'Approve-ElevatedAccessRequest',
        'Check-ExoInformationBarrierSymmetry',
        'Clear-ActiveSyncDevice',
        'Clear-MobileDevice',
        'Clear-TextMessagingAccount',
        'Compare-TextMessagingVerificationCode',
        'Deny-ElevatedAccessRequest',
        'Disable-App',
        'Disable-InboxRule',
        'Disable-SweepRule',
        'Enable-App',
        'Enable-ExoInformationBarriersMultiSegment',
        'Enable-InboxRule',
        'Enable-SweepRule',
        'Export-ApplicationData',
        'Export-MailboxDiagnosticLogs',
        'Export-TransportRuleCollection',
        'Get-AcceptedDomain',
        'Get-AccessToCustomerDataRequest',
        'Get-ActiveSyncDevice',
        'Get-ActiveSyncDeviceAccessRule',
        'Get-ActiveSyncDeviceClass',
        'Get-ActiveSyncDeviceStatistics',
        'Get-ActiveSyncMailboxPolicy',
        'Get-ActiveSyncOrganizationSettings',
        'Get-AdaptiveScope',
        'Get-AddressBookPolicy',
        'Get-AdminAuditLogConfig',
        'Get-AdministrativeUnit',
        'Get-AggregateZapReport',
        'Get-AntiPhishPolicy',
        'Get-AntiPhishRule',
        'Get-App',
        'Get-ApplicationAccessPolicy',
        'Get-ArcConfig',
        'Get-ATPBuiltInProtectionRule',
        'Get-ATPEvaluationRule',
        'Get-AtpPolicyForO365',
        'Get-ATPProtectionPolicyRule',
        'Get-ATPTotalTrafficReport',
        'Get-AuditConfig',
        'Get-AuditConfigurationPolicy',
        'Get-AuditConfigurationRule',
        'Get-AuditLogSearch',
        'Get-AuthenticationPolicy',
        'Get-AuthServer',
        'Get-BlockedConnector',
        'Get-BlockedSenderAddress',
        'Get-BookingMailbox',
        'Get-CalendarDiagnosticAnalysis',
        'Get-CalendarDiagnosticLog',
        'Get-CalendarDiagnosticObjects',
        'Get-CalendarProcessing',
        'Get-CalendarSettings',
        'Get-CalendarViewDiagnostics',
        'Get-CASMailbox',
        'Get-CASMailboxPlan',
        'Get-ClassificationRuleCollection',
        'Get-Clutter',
        'Get-ComplianceTag',
        'Get-ComplianceTagStorage',
        'Get-CompromisedUserAggregateReport',
        'Get-CompromisedUserDetailReport',
        'Get-ConfigAnalyzerPolicyRecommendation',
        'Get-Contact',
        'Get-ContentMalwareMdoAggregateReport',
        'Get-ContentMalwareMdoDetailReport',
        'Get-CrossTenantAccessPolicy',
        'Get-CustomDlpEmailTemplates',
        'Get-DataClassification',
        'Get-DataClassificationConfig',
        'Get-DataEncryptionPolicy',
        'Get-DetailZapReport',
        'Get-DeviceComplianceDetailsReport',
        'Get-DeviceComplianceDetailsReportFilter',
        'Get-DeviceCompliancePolicyInventory',
        'Get-DeviceComplianceReportDate',
        'Get-DeviceComplianceSummaryReport',
        'Get-DeviceComplianceUserInventory',
        'Get-DeviceComplianceUserReport',
        'Get-DeviceConditionalAccessPolicy',
        'Get-DeviceConditionalAccessRule',
        'Get-DeviceConfigurationPolicy',
        'Get-DeviceConfigurationRule',
        'Get-DevicePolicy',
        'Get-DeviceTenantPolicy',
        'Get-DeviceTenantRule',
        'Get-DistributionGroup',
        'Get-DistributionGroupMember',
        'Get-DkimSigningConfig',
        'Get-DlpDetailReport',
        'Get-DlpDetectionsReport',
        'Get-DlpIncidentDetailReport',
        'Get-DlpKeywordDictionary',
        'Get-DlpPolicy',
        'Get-DlpPolicyTemplate',
        'Get-DlpSensitiveInformationTypeConfig',
        'Get-DlpSensitiveInformationTypeRulePackage',
        'Get-DlpSiDetectionsReport',
        'Get-DnssecStatusForVerifiedDomain',
        'Get-DynamicDistributionGroup',
        'Get-DynamicDistributionGroupMember',
        'Get-ElevatedAccessApprovalPolicy',
        'Get-ElevatedAccessAuthorization',
        'Get-ElevatedAccessRequest',
        'Get-EligibleDistributionGroupForMigration',
        'Get-EmailTenantSettings',
        'Get-EOPProtectionPolicyRule',
        'Get-EtrLimits',
        'Get-EvaluationModeReport',
        'Get-EvaluationModeReportSeries',
        'Get-EventsFromEmailConfiguration',
        'Get-ExoConnectivityTableSnapshot',
        'Get-ExoInformationBarrierPolicy',
        'Get-ExoInformationBarrierRelationship',
        'Get-ExoInformationBarrierRelationshipTable',
        'Get-ExoInformationBarrierSegment',
        'Get-ExoInformationBarrierUpgradeImpact',
        'Get-ExoPhishSimOverrideRule',
        'Get-ExoRecipientsStatus',
        'Get-ExoSecOpsOverrideRule',
        'Get-ExoSegmentsSnapshot',
        'Get-ExoUsersByIBSegment',
        'Get-ExternalInOutlook',
        'Get-FailedContentIndexDocuments',
        'Get-FederatedOrganizationIdentifier',
        'Get-FederationInformation',
        'Get-FederationTrust',
        'Get-FfoMigrationReport',
        'Get-Group',
        'Get-HistoricalSearch',
        'Get-HostedConnectionFilterPolicy',
        'Get-HostedContentFilterPolicy',
        'Get-HostedContentFilterRule',
        'Get-HostedOutboundSpamFilterPolicy',
        'Get-HostedOutboundSpamFilterRule',
        'Get-HybridMailflowDatacenterIPs',
        'Get-InboundConnector',
        'Get-InboxRule',
        'Get-InformationBarrierReportDetails',
        'Get-InformationBarrierReportSummary',
        'Get-IntraOrganizationConfiguration',
        'Get-IntraOrganizationConnector',
        'Get-IPv6StatusForAcceptedDomain',
        'Get-IRMConfiguration',
        'Get-JitConfiguration',
        'Get-JournalRule',
        'Get-LinkedUser',
        'Get-LogonStatistics',
        'Get-M365CrossTenantAccessPolicy',
        'Get-M365DataAtRestEncryptionPolicy',
        'Get-Mailbox',
        'Get-MailboxAnalysisRequest',
        'Get-MailboxAnalysisRequestStatistics',
        'Get-MailboxAuditBypassAssociation',
        'Get-MailboxAutoReplyConfiguration',
        'Get-MailboxCalendarConfiguration',
        'Get-MailboxCalendarFolder',
        'Get-MailboxFolder',
        'Get-MailboxFolderPermission',
        'Get-MailboxFolderStatistics',
        'Get-MailboxIRMAccess',
        'Get-MailboxJunkEmailConfiguration',
        'Get-MailboxLocation',
        'Get-MailboxMessageConfiguration',
        'Get-MailboxOverrideConfiguration',
        'Get-MailboxPermission',
        'Get-MailboxPlan',
        'Get-MailboxRegionalConfiguration',
        'Get-MailboxSpellingConfiguration',
        'Get-MailboxStatistics',
        'Get-MailboxUserConfiguration',
        'Get-MailContact',
        'Get-MailDetailATPReport',
        'Get-MailDetailEncryptionReport',
        'Get-MailDetailEvaluationModeReport',
        'Get-MailDetailTransportRuleReport',
        'Get-MailFilterListReport',
        'Get-MailFlowStatusReport',
        'Get-MailPublicFolder',
        'Get-MailTrafficATPReport',
        'Get-MailTrafficEncryptionReport',
        'Get-MailTrafficPolicyReport',
        'Get-MailTrafficSummaryReport',
        'Get-MailUser',
        'Get-MalwareFilterPolicy',
        'Get-MalwareFilterRule',
        'Get-ManagementRole',
        'Get-ManagementRoleAssignment',
        'Get-ManagementRoleEntry',
        'Get-ManagementScope',
        'Get-MeetingInsightsSettings',
        'Get-MessageCategory',
        'Get-MessageClassification',
        'Get-MessageTrace',
        'Get-MessageTraceCopilot',
        'Get-MessageTraceDetail',
        'Get-MessageTraceDetailV2',
        'Get-MessageTraceV2',
        'Get-MessageTrackingReport',
        'Get-MigrationBatch',
        'Get-MigrationConfig',
        'Get-MigrationEndpoint',
        'Get-MigrationStatistics',
        'Get-MigrationUser',
        'Get-MigrationUserStatistics',
        'Get-MobileDevice',
        'Get-MobileDeviceDashboardSummaryReport',
        'Get-MobileDeviceMailboxPolicy',
        'Get-MobileDeviceStatistics',
        'Get-MoveRequest',
        'Get-MoveRequestStatistics',
        'Get-MxRecordReport',
        'Get-MxRecordsReport',
        'Get-Notification',
        'Get-OMEConfiguration',
        'Get-OnlineMeetingConfiguration',
        'Get-OnPremisesOrganization',
        'Get-OnPremServerExemptionQuota',
        'Get-OnPremServerReportInfo',
        'Get-OrganizationalUnit',
        'Get-OrganizationConfig',
        'Get-OrganizationRelationship',
        'Get-OutboundConnector',
        'Get-OutboundConnectorReport',
        'Get-OutlookProtectionRule',
        'Get-OwaMailboxPolicy',
        'Get-PartnerApplication',
        'Get-PendingDelicenseUser',
        'Get-PerimeterConfig',
        'Get-PerimeterMessageTrace',
        'Get-PhishSimOverridePolicy',
        'Get-Place',
        'Get-PolicyConfig',
        'Get-PolicyTipConfig',
        'Get-PublicFolder',
        'Get-PublicFolderClientPermission',
        'Get-PublicFolderItemStatistics',
        'Get-PublicFolderMailboxDiagnostics',
        'Get-PublicFolderMailboxMigrationRequest',
        'Get-PublicFolderMailboxMigrationRequestStatistics',
        'Get-PublicFolderStatistics',
        'Get-QuarantineMessage',
        'Get-QuarantineMessageHeader',
        'Get-QuarantinePolicy',
        'Get-RbacDiagnosticInfo',
        'Get-Recipient',
        'Get-RecipientStatisticsReport',
        'Get-RemoteDomain',
        'Get-ReportExecutionInstance',
        'Get-ReportSchedule',
        'Get-ReportScheduleList',
        'Get-ReportSubmissionPolicy',
        'Get-ReportSubmissionRule',
        'Get-RetentionPolicy',
        'Get-RetentionPolicyTag',
        'Get-RMSTemplate',
        'Get-RoleAssignmentPolicy',
        'Get-RoleGroup',
        'Get-RoleGroupMember',
        'Get-SafeAttachmentPolicy',
        'Get-SafeAttachmentRule',
        'Get-SafeLinksAggregateReport',
        'Get-SafeLinksDetailReport',
        'Get-SafeLinksPolicy',
        'Get-SafeLinksRule',
        'Get-SCInsights',
        'Get-ScopeEntities',
        'Get-SearchDocumentFormat',
        'Get-SecOpsOverridePolicy',
        'Get-SensitivityLabelActivityDetailsReport',
        'Get-SensitivityLabelActivityReport',
        'Get-ServiceDeliveryReport',
        'Get-ServiceStatus',
        'Get-SharingPolicy',
        'Get-SmimeConfig',
        'Get-SmtpDaneInboundStatus',
        'Get-SpoofIntelligenceInsight',
        'Get-SpoofMailReport',
        'Get-SupervisoryReviewActivity',
        'Get-SupervisoryReviewPolicyReport',
        'Get-SupervisoryReviewPolicyV2',
        'Get-SupervisoryReviewReport',
        'Get-SupervisoryReviewRule',
        'Get-SweepRule',
        'Get-SyncConfig',
        'Get-SyncRequest',
        'Get-SyncRequestStatistics',
        'Get-TeamsProtectionPolicy',
        'Get-TeamsProtectionPolicyRule',
        'Get-TenantAllowBlockListItems',
        'Get-TenantAllowBlockListSpoofItems',
        'Get-TenantExemptionInfo',
        'Get-TenantExemptionQuota',
        'Get-TenantExemptionQuotaEligibility',
        'Get-TenantRecipientLimitInfo',
        'Get-TenantScanRequestStatistics',
        'Get-TextMessagingAccount',
        'Get-ToolInformation',
        'Get-TransportConfig',
        'Get-TransportRule',
        'Get-TransportRuleAction',
        'Get-TransportRulePredicate',
        'Get-UnifiedAuditSetting',
        'Get-UnifiedGroup',
        'Get-UnifiedGroupLinks',
        'Get-User',
        'Import-RecipientDataProperty',
        'New-App',
        'New-DistributionGroup',
        'New-ElevatedAccessRequest',
        'New-InboxRule',
        'New-MailboxFolder',
        'New-MailMessage',
        'New-PrivilegedIdentityManagementRequest',
        'New-ProtectionServicePolicy',
        'New-SchedulingMailbox',
        'New-SweepRule',
        'New-TenantExemptionInfo',
        'New-TenantExemptionQuota',
        'Remove-ActiveSyncDevice',
        'Remove-App',
        'Remove-AuditConfigurationPolicy',
        'Remove-AuditConfigurationRule',
        'Remove-BookingMailbox',
        'Remove-DistributionGroup',
        'Remove-DistributionGroupMember',
        'Remove-ExoInformationBarriersV1Configuration',
        'Remove-InboxRule',
        'Remove-M365CrossTenantAccessPolicy',
        'Remove-MailboxAnalysisRequest',
        'Remove-MailboxFolderPermission',
        'Remove-MailboxUserConfiguration',
        'Remove-MobileDevice',
        'Remove-PublicFolderMailboxMigrationRequest',
        'Remove-SweepRule',
        'Remove-SyncRequest',
        'Reset-EventsFromEmailBlockStatus',
        'Revoke-ElevatedAccessAuthorization',
        'Search-MessageTrackingReport',
        'Send-TextMessagingVerificationCode',
        'Set-AccessToCustomerDataRequest',
        'Set-BookingMailboxPermission',
        'Set-CalendarProcessing',
        'Set-CASMailbox',
        'Set-Clutter',
        'Set-DistributionGroup',
        'Set-DynamicDistributionGroup',
        'Set-ElevatedAccessRequest',
        'Set-EventsFromEmailConfiguration',
        'Set-ExternalInOutlook',
        'Set-Group',
        'Set-InboxRule',
        'Set-LabelProperties',
        'Set-Mailbox',
        'Set-MailboxAutoReplyConfiguration',
        'Set-MailboxCalendarConfiguration',
        'Set-MailboxCalendarFolder',
        'Set-MailboxFolderPermission',
        'Set-MailboxJunkEmailConfiguration',
        'Set-MailboxMessageConfiguration',
        'Set-MailboxRegionalConfiguration',
        'Set-MailboxSpellingConfiguration',
        'Set-MailUser',
        'Set-ProtectionServicePolicy',
        'Set-RegulatoryComplianceUI',
        'Set-ReportSchedule',
        'Set-RetentionPolicyTag',
        'Set-SmimeConfig',
        'Set-SweepRule',
        'Set-TextMessagingAccount',
        'Set-UnifiedAuditSetting',
        'Set-User',
        'Start-AuditAssistant',
        'Start-HistoricalSearch',
        'Stop-HistoricalSearch',
        'Test-ApplicationAccessPolicy',
        'Test-DatabaseEvent',
        'Test-DataEncryptionPolicy',
        'Test-DlpPolicies',
        'Test-M365DataAtRestEncryptionPolicy',
        'Test-MailboxAssistant',
        'Test-Message',
        'Test-OrganizationRelationship',
        'Troubleshoot-AgendaMail',
        'Update-DistributionGroupMember',
        'Upgrade-DistributionGroup',
        'Validate-RetentionRuleQuery'
    )
    #endregion EXORemoteModuleCommands

    $FileDependencies = New-Object System.Collections.Generic.List[PSCustomObject]
    $Files = Get-ChildItem -Path $Path -File *.ps1 -Recurse
    foreach ($file in $Files) {
        $Content = Get-Content $file -Raw
        $Parse = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $Commands = $parse.FindAll({
                $args | Where-Object { $_ -is [System.Management.Automation.Language.CommandAst] }
            }, $true) | ForEach-Object {
                ($_.CommandElements | Select-Object -First 1).Value
        } | Group-Object | Sort-Object @{e = { $_.Count }; Descending = $true }, Name

        foreach ($command in $Commands) {
            $FileDependencies.Add( [PSCustomObject]@{
                    Command = $command.Name
                    Count   = $command.Count
                    File    = $file
                } )
        }
    }

    # Loop through $FileDependencies. Create a list of custom objects that contain the command name, the number of times it appears, and the files it appears in.
    $DependencyList = New-Object System.Collections.Generic.List[PSCustomObject]
    foreach ($item in $FileDependencies) {
        # Check if $DependencyList already contains an object with the same command name.
        if ($DependencyList.command -contains $item.command) {
            # If it is already in the list, increment the count and add the file to the files array.
            $ListItem = $DependencyList | Where-Object { $_.command -eq $item.command }
            $ListItem.count = $ListItem.count + $item.count
            $ListItem.files += $item.file
            continue
        } else {
            # Create a new item in the list.
            $Module = (Get-Command -Name $item.command -ErrorAction SilentlyContinue).Source
            if ( [string]::IsNullOrEmpty($Module) -and $InternalFunctions -contains $item.command ) {
                $Module = 'Maester (Internal Function)'
            }
            if ( [string]::IsNullOrEmpty($Module) -and $EXORemoteModuleCommands -contains $item.command ) {
                $Module = 'ExchangeOnlineManagement (Remote Module)'
            }

            $DependencyList.Add( [PSCustomObject]@{
                    Command = $item.command
                    Module  = $Module
                    Count   = $item.count
                    Files   = @($item.file)
                } )
        }
    }

    $DependencyList = $DependencyList | Sort-Object -Property Module, Count, Name
    $DependencyList | Where-Object -FilterScript $Filter

}
