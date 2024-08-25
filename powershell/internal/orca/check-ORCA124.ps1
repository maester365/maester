# Generated on 08/24/2024 20:37:39 by .\build\orca\Update-OrcaTests.ps1

<#

ORCA-124 Checks to determine if Safe attachments unknown malware response set to block

#>

using module Maester

class ORCA124 : ORCACheck
{
    <#
    
        CONSTRUCTOR with Check Header Data
    
    #>

    ORCA124()
    {
        $this.Control=124
        $this.Services=[ORCAService]::MDO
        $this.Area="Microsoft Defender for Office 365 Policies"
        $this.Name="Safe attachments unknown malware response"
        $this.PassText="Safe attachments unknown malware response set to block messages"
        $this.FailRecommendation="Set Safe attachments unknown malware response to block messages"
        $this.Importance="When Safe attachments unknown malware response set to block, Microsoft Defender for Office 365 prevents current and future messages with detected malware from proceeding and sends messages to quarantine in Office 365."
        $this.ExpandResults=$True
        $this.CheckType=[CheckType]::ObjectPropertyValue
        $this.ObjectType="Safe Attachments Policy"
        $this.ItemName="Setting"
        $this.DataType="Current Value"
        $this.ChiValue=[ORCACHI]::Medium
        $this.Links= @{
            "Microsoft 365 Defender Portal - Safe attachments"="https://security.microsoft.com/safeattachmentv2"
            "Recommended settings for EOP and Microsoft Defender for Office 365 security"="https://aka.ms/orca-atpp-docs-7"
        }
    }

    <#
    
        RESULTS
    
    #>

    GetResults($Config)
    {

        <#
        
        This check does not need a default response where no policies exist,
        because the 'Built-In Protection Policy' has this turned on.
        
        #>
       
        ForEach($Policy in $Config["SafeAttachmentsPolicy"]) 
        {
            # Check objects
            $ConfigObject = [ORCACheckConfig]::new()
            $ConfigObject.Object=$Config["PolicyStates"][$Policy.Guid.ToString()].Name
            $ConfigObject.ConfigItem="Action"
            $ConfigObject.ConfigData=$($Policy.Action)
            $ConfigObject.ConfigReadonly=$Policy.IsPreset
            $ConfigObject.ConfigDisabled = $Config["PolicyStates"][$Policy.Guid.ToString()].Disabled
            $ConfigObject.ConfigWontApply = !$Config["PolicyStates"][$Policy.Guid.ToString()].Applies
            $ConfigObject.ConfigPolicyGuid=$Policy.Guid.ToString()
            
            # Determine if MDO Safe attachments action is set to block
            If($($Policy.Action) -ne "Block") 
            {
                $ConfigObject.SetResult([ORCAConfigLevel]::Standard,[ORCAResult]::Fail)
            } 
            Else 
            {
                $ConfigObject.SetResult([ORCAConfigLevel]::Standard,[ORCAResult]::Pass)
            }

            If($($Policy.Action) -eq "Replace" -or $($Policy.Action) -eq "DynamicDelivery")
            {
                $ConfigObject.InfoText = "Attachments with detected malware will be blocked, the body of the email message delivered to the recipient."
                $ConfigObject.SetResult([ORCAConfigLevel]::All,[ORCAResult]::Informational)
            }

            $this.AddConfig($ConfigObject)
        }

    }

}
