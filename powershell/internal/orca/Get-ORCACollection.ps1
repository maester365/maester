# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
param()

Function Get-ORCACollection
{
    Param (
        [Boolean]$SCC
    )

    $Collection = @{}

    [ORCAService]$Collection["Services"] = [ORCAService]::EOP

    # Determine if MDO is available by checking for presence of an MDO command
    if($(Get-command Get-AtpPolicyForO365 -ErrorAction:SilentlyContinue))
    {
        $Collection["Services"] += [ORCAService]::MDO
    } 

    If(!$Collection["Services"] -band [ORCAService]::MDO)
    {
        Write-Verbose "$(Get-Date) Microsoft Defender for Office 365 is not detected - these checks will be skipped!" -ForegroundColor Red
    }

    Write-Verbose "$(Get-Date) Getting Anti-Spam Settings"
    $Collection["HostedConnectionFilterPolicy"] = Get-HostedConnectionFilterPolicy
    $Collection["HostedContentFilterPolicy"] = Get-HostedContentFilterPolicy
    $Collection["HostedContentFilterRule"] = Get-HostedContentFilterRule
    $Collection["HostedOutboundSpamFilterPolicy"] = Get-HostedOutboundSpamFilterPolicy
    $Collection["HostedOutboundSpamFilterRule"] = Get-HostedOutboundSpamFilterRule

    If($Collection["Services"] -band [ORCAService]::MDO)
    {
        Write-Verbose "$(Get-Date) Getting MDO Preset Policy Settings"
        $Collection["ATPProtectionPolicyRule"] = Get-ATPProtectionPolicyRule
        $Collection["ATPBuiltInProtectionRule"] = Get-ATPBuiltInProtectionRule
    }

    if($SCC -and $Collection["Services"] -band [ORCAService]::MDO)
    {
        Write-Verbose "$(Get-Date) Getting Protection Alerts"
        $Collection["ProtectionAlert"] = Get-ProtectionAlert | Where-Object {$_.IsSystemRule}
    }

    Write-Verbose "$(Get-Date) Getting EOP Preset Policy Settings"
    $Collection["EOPProtectionPolicyRule"] = Get-EOPProtectionPolicyRule

    Write-Verbose "$(Get-Date) Getting Quarantine Policy Settings"
    $Collection["QuarantinePolicy"] =  Get-QuarantinePolicy
    $Collection["QuarantinePolicyGlobal"]  = Get-QuarantinePolicy -QuarantinePolicyType GlobalQuarantinePolicy

    If($Collection["Services"] -band [ORCAService]::MDO)
    {
        Write-Verbose "$(Get-Date) Getting Anti Phish Settings"
        $Collection["AntiPhishPolicy"] = Get-AntiphishPolicy
        $Collection["AntiPhishRules"] = Get-AntiPhishRule
    }

    Write-Verbose "$(Get-Date) Getting Anti-Malware Settings"
    $Collection["MalwareFilterPolicy"] = Get-MalwareFilterPolicy
    $Collection["MalwareFilterRule"] = Get-MalwareFilterRule

    Write-Verbose "$(Get-Date) Getting Transport Rules"
    $Collection["TransportRules"] = Get-TransportRule

    If($Collection["Services"] -band [ORCAService]::MDO)
    {
        Write-Verbose "$(Get-Date) Getting MDO Policies"
        $Collection["SafeAttachmentsPolicy"] = Get-SafeAttachmentPolicy
        $Collection["SafeAttachmentsRules"] = Get-SafeAttachmentRule
        $Collection["SafeLinksPolicy"] = Get-SafeLinksPolicy
        $Collection["SafeLinksRules"] = Get-SafeLinksRule
        $Collection["AtpPolicy"] = Get-AtpPolicyForO365
    }

    Write-Verbose "$(Get-Date) Getting Accepted Domains"
    $Collection["AcceptedDomains"] = Get-AcceptedDomain

    Write-Verbose "$(Get-Date) Getting DKIM Configuration"
    $Collection["DkimSigningConfig"] = Get-DkimSigningConfig

    Write-Verbose "$(Get-Date) Getting Connectors"
    $Collection["InboundConnector"] = Get-InboundConnector

    Write-Verbose "$(Get-Date) Getting Outlook External Settings"
    $Collection["ExternalInOutlook"] = Get-ExternalInOutlook

    # Required for Enhanced Filtering checks
    Write-Verbose "$(Get-Date) Getting MX Reports for all domains"
    $Collection["MXReports"] = @()
    ForEach($d in $Collection["AcceptedDomains"])
    {
        Try
        {
            $Collection["MXReports"] += Get-MxRecordReport -Domain $($d.DomainName) -ErrorAction:SilentlyContinue
        }
        Catch
        {
            Write-Verbose "$(Get-Date) Failed to get MX report for domain $($d.DomainName)"
        }
        
    }

    # ARC Settings
    Write-Verbose "$(Get-Date) Getting ARC Config"
    $Collection["ARCConfig"] = Get-ArcConfig

    # Determine policy states
    Write-Verbose "$(Get-Date) Determining applied policy states"

    $Collection["PolicyStates"] = Get-PolicyStates -AntiphishPolicies $Collection["AntiPhishPolicy"] -AntiphishRules $Collection["AntiPhishRules"] -AntimalwarePolicies $Collection["MalwareFilterPolicy"] -AntimalwareRules $Collection["MalwareFilterRule"] -AntispamPolicies $Collection["HostedContentFilterPolicy"] -AntispamRules $Collection["HostedContentFilterRule"] -SafeLinksPolicies $Collection["SafeLinksPolicy"] -SafeLinksRules $Collection["SafeLinksRules"] -SafeAttachmentsPolicies $Collection["SafeAttachmentsPolicy"] -SafeAttachmentRules $Collection["SafeAttachmentsRules"] -ProtectionPolicyRulesATP $Collection["ATPProtectionPolicyRule"] -ProtectionPolicyRulesEOP $Collection["EOPProtectionPolicyRule"] -OutboundSpamPolicies $Collection["HostedOutboundSpamFilterPolicy"] -OutboundSpamRules $Collection["HostedOutboundSpamFilterRule"] -BuiltInProtectionRule $Collection["ATPBuiltInProtectionRule"]
    $Collection["AnyPolicyState"] = Get-AnyPolicyState -PolicyStates $Collection["PolicyStates"]

    # Add IsPreset properties for Preset policies (where applicable)
    Add-IsPresetValue -CollectionEntity $Collection["HostedContentFilterPolicy"]
    Add-IsPresetValue -CollectionEntity $Collection["EOPProtectionPolicyRule"]

    If($Collection["Services"] -band [ORCAService]::MDO)
    {
        Add-IsPresetValue -CollectionEntity $Collection["ATPProtectionPolicyRule"]
        Add-IsPresetValue -CollectionEntity $Collection["AntiPhishPolicy"]
        Add-IsPresetValue -CollectionEntity $Collection["SafeAttachmentsPolicy"]
        Add-IsPresetValue -CollectionEntity $Collection["SafeLinksPolicy"] 
    }

    Return $Collection
}
