# Generated on 10/25/2024 16:51:13 by .\build\orca\Update-OrcaTests.ps1

<#

158 Checks to determine if MDO is enabled for SharePoint, Teams, and OD4B as per 'tickbox' in the MDO configuration.

#>

using module Maester

class ORCA158 : ORCACheck
{
    <#
    
        CONSTRUCTOR with Check Header Data
    
    #>

    ORCA158()
    {
        $this.Control=158
        $this.Services=[ORCAService]::MDO
        $this.Area="Microsoft Defender for Office 365 Policies"
        $this.Name="Safe Attachments SharePoint and Teams"
        $this.PassText="Safe Attachments is enabled for SharePoint and Teams"
        $this.FailRecommendation="Enable Safe Attachments for SharePoint and Teams"
        $this.Importance="Safe Attachments can assist by scanning for zero day malware by using behavioural analysis and sandboxing techniques. These checks suppliment signature definitions."
        $this.ExpandResults=$True
        $this.CheckType=[CheckType]::ObjectPropertyValue
        $this.ObjectType="Safe Attachments Policy"
        $this.ItemName="Setting"
        $this.DataType="Current Value"
        $this.ChiValue=[ORCACHI]::High
        $this.Links= @{
            "Microsoft 365 Defender Portal - Safe attachments"="https://security.microsoft.com/safeattachmentv2"
            "Recommended settings for EOP and Microsoft Defender for Office 365"="https://aka.ms/orca-atpp-docs-7"
        }
    }

    <#
    
        RESULTS
    
    #>

    GetResults($Config)
    {

        $ConfigObject = [ORCACheckConfig]::new()
        $ConfigObject.Object=$Config["AtpPolicy"].Name
        $ConfigObject.ConfigItem="EnableATPForSPOTeamsODB"
        $ConfigObject.ConfigData=$Config["AtpPolicy"].EnableATPForSPOTeamsODB
        
        # Determine if MDO is enabled or not
        If($Config["AtpPolicy"].EnableATPForSPOTeamsODB -eq $false) 
        {
            $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Fail")   
        }
        Else
        {
            $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Pass")     
        }
        
        $this.AddConfig($ConfigObject)

    }

}
