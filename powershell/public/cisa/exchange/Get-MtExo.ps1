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

.EXAMPLE
    Get-MtAcceptedDomain

    Returns accepted domains for a tenant

.LINK
    https://maester.dev/docs/commands/Get-MtExo
#>
function Get-MtExo {
    [Alias(
        "Get-MtAcceptedDomain",
        "Get-MtRemoteDomain",
        "Get-MtTransportConfig",
        "Get-MtTransportRule",
        "Get-MtOrganizationConfig",
        "Get-MtDkimSigningConfig",
        "Get-MtSharingPolicy",
        "Get-MtDlpComplianceRule",
        "Get-MtDlpCompliancePolicy",
        "Get-MtMalwareFilterPolicy",
        "Get-MtHostedContentFilterPolicy",
        "Get-MtAntiPhishPolicy",
        "Get-MtSafeAttachmentPolicy",
        "Get-MtSafeLinksPolicy",
        "Get-MtATPBuiltInProtectionRule",
        "Get-MtEOPProtectionPolicyRule",
        "Get-MtATPProtectionPolicyRule"
    )]
    [CmdletBinding()]
    [OutputType([string],[object[]],[psobject])]
    param(
        [string] $Request = ($MyInvocation.InvocationName).Substring(6)
    )
    <#
    $policies = @{
        "HostedContentFilterPolicy" = Get-HostedContentFilterPolicy #RecommendedPolicyType -eq "Standard", "Strict"
        "AntiPhishPolicy"           = Get-AntiPhishPolicy #RecommendedPolicyType -eq "Standard", "Strict"
        "SafeAttachmentPolicy"      = Get-SafeAttachmentPolicy #RecommendedPolicyType -eq "Standard", "Strict"
        "SafeLinksPolicy"           = Get-SafeLinksPolicy #RecommendedPolicyType -eq "Standard", "Strict"
        "ATPBuiltInProtectionRule"  = Get-ATPBuiltInProtectionRule
        "EOPProtectionPolicyRule"   = Get-EOPProtectionPolicyRule #-Identity "*Preset Security Policy" #IsBuiltInProtection
        "ATPProtectionPolicyRule"   = Get-ATPProtectionPolicyRule #-Identity "*Preset Security Policy" #IsBuiltInProtection
    }
    #>

    ### To add new commands
    ### - add them to the hashtable below
    ### - add them as an alias
    ### - confirm the command's return type is in OutputType (e.g. (Get-AcceptedDomain).GetType().Name)
    $commands = @{
        "AcceptedDomain"            = "Get-AcceptedDomain"
        "RemoteDomain"              = "Get-RemoteDomain"
        "TransportConfig"           = "Get-TransportConfig"
        "TransportRule"             = "Get-TransportRule"
        "OrganizationConfig"        = "Get-OrganizationConfig"
        "DkimSigningConfig"         = "Get-DkimSigningConfig"
        "SharingPolicy"             = "Get-SharingPolicy"
        "DlpComplianceRule"         = "Get-DlpComplianceRule"
        "DlpCompliancePolicy"       = "Get-DlpCompliancePolicy"
        "MalwareFilterPolicy"       = "Get-MalwareFilterPolicy"
        "HostedContentFilterPolicy" = "Get-HostedContentFilterPolicy"
        "AntiPhishPolicy"           = "Get-AntiPhishPolicy"
        "SafeAttachmentPolicy"      = "Get-SafeAttachmentPolicy"
        "SafeLinksPolicy"           = "Get-SafeLinksPolicy"
        "ATPBuiltInProtectionRule"  = "Get-ATPBuiltInProtectionRule"
        "EOPProtectionPolicyRule"   = "Get-EOPProtectionPolicyRule"
        "ATPProtectionPolicyRule"   = "Get-ATPProtectionPolicyRule"
    }


    if($Request -eq "Exo"){
        Write-Error "$($MyInvocation.InvocationName) called with invalid -Request, specify value (e.g., AcceptedDomain)"
        return "Unable to obtain policy"
    }elseif($Request -notin $commands.Keys){
        Write-Error "$($MyInvocation.InvocationName) called with unsupported -Request"
        return "Unable to obtain policy"
    }

    if($null -eq $__MtSession.ExoCache.$Request){
        Write-Verbose "$request not in cache, requesting."
        $response = Invoke-Expression $commands.$Request
        $__MtSession.ExoCache.$Request = $response
    }else{
        Write-Verbose "$request in cache."
        $response = $__MtSession.ExoCache.$Request
    }

    return $response
}