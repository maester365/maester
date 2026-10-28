function Get-MtExo {
    <#
    .SYNOPSIS
    Retrieves cached response or requests from cmdlet

    .DESCRIPTION
    Manages the EXO cmdlet caching

    .PARAMETER Request
    Provide the name of the EXO Cmdlet without the Get- prepended (e.g. Get-AcceptedDomain = -Request AcceptedDomain)

    .EXAMPLE
    Get-MtExo -Request AcceptedDomain

    Returns accepted domains for a tenant

    .LINK
    https://maester.dev/docs/commands/Get-MtExo
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
    [CmdletBinding()]
    [OutputType([string], [object[]], [psobject])]
    param(
        [string] $Request = ($MyInvocation.InvocationName).Substring(6)
    )
    <#
    $policies = @{
        "SafeAttachmentPolicy"      = Get-SafeAttachmentPolicy #RecommendedPolicyType -eq "Standard", "Strict"
        "ATPBuiltInProtectionRule"  = Get-ATPBuiltInProtectionRule
        "EOPProtectionPolicyRule"   = Get-EOPProtectionPolicyRule #-Identity "*Preset Security Policy" #IsBuiltInProtection
        "ATPProtectionPolicyRule"   = Get-ATPProtectionPolicyRule #-Identity "*Preset Security Policy" #IsBuiltInProtection
    }
    #>

    ### To add new commands
    ### - add them to the hashtable below
    ### - confirm the command's return type is in OutputType (e.g. (Get-AcceptedDomain).GetType().Name)
    $commands = @{
        "AcceptedDomain"                 = "Get-AcceptedDomain"
        "RemoteDomain"                   = "Get-RemoteDomain"
        "TransportConfig"                = "Get-TransportConfig"
        "TransportRule"                  = "Get-TransportRule"
        "OrganizationConfig"             = "Get-OrganizationConfig"
        "DkimSigningConfig"              = "Get-DkimSigningConfig"
        "SharingPolicy"                  = "Get-SharingPolicy"
        "DlpComplianceRule"              = "Get-DlpComplianceRule"
        "DlpCompliancePolicy"            = "Get-DlpCompliancePolicy"
        "RetentionCompliancePolicy"      = "Get-RetentionCompliancePolicy"
        "AppRetentionCompliancePolicy"   = "Get-AppRetentionCompliancePolicy"
        "MalwareFilterPolicy"            = "Get-MalwareFilterPolicy"
        "HostedContentFilterPolicy"      = "Get-HostedContentFilterPolicy"
        "HostedConnectionFilterPolicy"   = "Get-HostedConnectionFilterPolicy"
        "AntiPhishPolicy"                = "Get-AntiPhishPolicy"
        "SafeAttachmentPolicy"           = "Get-SafeAttachmentPolicy"
        "SafeLinksPolicy"                = "Get-SafeLinksPolicy"
        "HostedOutboundSpamFilterPolicy" = "Get-HostedOutboundSpamFilterPolicy"
        "AtpPolicyForO365"               = "Get-AtpPolicyForO365"
        "ATPBuiltInProtectionRule"       = "Get-ATPBuiltInProtectionRule"
        "EOPProtectionPolicyRule"        = "Get-EOPProtectionPolicyRule"
        "ATPProtectionPolicyRule"        = "Get-ATPProtectionPolicyRule"
        "ProtectionAlert"                = "Get-ProtectionAlert"
        "EXOMailbox"                     = "Get-EXOMailbox -ResultSize 'Unlimited'"
        "EXOSharedMailbox"               = "Get-EXOMailbox -RecipientTypeDetails 'SharedMailbox' -ResultSize 'Unlimited'"
        "ArcConfig"                      = "Get-ArcConfig"
        "ExternalInOutlook"              = "Get-ExternalInOutlook"
        "InboundConnector"               = "Get-InboundConnector"
        "SafeLinksRule"                  = "Get-SafeLinksRule"
        "SafeAttachmentRule"             = "Get-SafeAttachmentRule"
        "MalwareFilterRule"              = "Get-MalwareFilterRule"
        "AntiPhishRule"                  = "Get-AntiPhishRule"
        "QuarantinePolicy"               = "Get-QuarantinePolicy"
        "HostedOutboundSpamFilterRule"   = "Get-HostedOutboundSpamFilterRule"
        "HostedContentFilterRule"        = "Get-HostedContentFilterRule"
        "OwaMailboxPolicy"               = "Get-OwaMailboxPolicy"
        "RoleAssignmentPolicy"           = "Get-RoleAssignmentPolicy"
        "ManagementRoleAssignment"       = "Get-ManagementRoleAssignment"
        "ConnectionInformation"          = "Get-ConnectionInformation"
        "AdminAuditLogConfig"            = "Get-AdminAuditLogConfig"
        "EXOMailboxAudit"                = "Get-EXOMailbox -RecipientTypeDetails 'UserMailbox' -PropertySets 'Audit','Minimum' -ResultSize 'Unlimited'"
        "MailboxAuditBypassAssociation"  = "Get-MailboxAuditBypassAssociation -ResultSize 'Unlimited' -WarningAction 'SilentlyContinue'"
        "EmailTenantSettings"            = "Get-EmailTenantSettings"
        "VipUser"                        = "`$connection = Get-ConnectionInformation | Where-Object { `$_.IsEopSession -ne `$true -and `$_.State -eq 'Connected' } | Select-Object -First 1; `$moduleName = if (`$connection.ModuleName) { Split-Path -Path `$connection.ModuleName -Leaf }; `$exo = if (`$moduleName) { Get-Module -Name `$moduleName }; if (-not `$exo -or -not `$exo.ExportedCommands.ContainsKey('Get-User') -or -not `$exo.ExportedCommands['Get-User'].Parameters.ContainsKey('IsVIP')) { throw 'Get-User -IsVIP is not available. Connect to Exchange Online with Connect-ExchangeOnline.' }; & `$exo { Get-User -IsVIP -ResultSize 'Unlimited' }"
        "LabelPolicy"                    = "Get-LabelPolicy -WarningAction 'SilentlyContinue'"
        "EXOMailboxRoleAssignmentPolicy" = "Get-EXOMailbox -RecipientTypeDetails 'UserMailbox' -Properties 'RoleAssignmentPolicy' -ResultSize 'Unlimited'"
    }


    if ($Request -eq "Exo") {
        Write-Error "$($MyInvocation.InvocationName) called with invalid -Request, specify value (e.g., AcceptedDomain)"
        return "Unable to obtain policy"
    }
    elseif ($Request -notin $commands.Keys) {
        Write-Error "$($MyInvocation.InvocationName) called with unsupported -Request"
        return "Unable to obtain policy"
    }

    if ($null -eq $__MtSession.ExoCache.$Request) {
        Write-Verbose "$request not in cache, requesting."
        if ($Request -eq "AdminAuditLogConfig") {
            # Connect-IPPSSession also exports Get-AdminAuditLogConfig, and its copy reports
            # UnifiedAuditLogIngestionEnabled as False (#1802). Use an Exchange Online module that exports it.
            $exoModule = Get-MtExo -Request ConnectionInformation |
            Where-Object { $_.IsEopSession -ne $true -and $_.State -eq 'Connected' } |
            Where-Object {
                $candidateModuleName = Split-Path -Path $_.ModuleName -Leaf
                $candidateModule = Get-Module -Name $candidateModuleName
                $candidateModule -and $candidateModule.ExportedCommands.ContainsKey('Get-AdminAuditLogConfig')
            } |
            Select-Object -First 1 -ExpandProperty ModuleName
            if ($exoModule) {
                $exoModuleName = Split-Path -Path $exoModule -Leaf
                $commands.$Request = "$exoModuleName\Get-AdminAuditLogConfig"
            }
        }
        $response = Invoke-Expression $commands.$Request -ErrorAction Stop
        $__MtSession.ExoCache.$Request = $response
    }
    else {
        Write-Verbose "$request in cache."
        $response = $__MtSession.ExoCache.$Request
    }

    return $response
}
