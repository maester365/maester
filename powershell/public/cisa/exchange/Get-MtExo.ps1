<#
.SYNOPSIS
    Retrieves cached response or requests from cmdlet

.DESCRIPTION
    Manages the EXO cmdlet caching

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

    if($Request -eq "Exo"){
        Write-Error "$($MyInvocation.InvocationName) called with invalid -Request"
        return "Unable to obtain policy"
    }

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

    if($null -eq $__MtSession.ExoCache.$Request){
        $response = $commands.$Request
        $__MtSession.ExoCache.$Request = $response
    }else{
        $response = $__MtSession.ExoCache.$Request
    }

    return $response
}