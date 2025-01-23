# Generated on 01/19/2025 07:06:35 by .\build\orca\Update-OrcaTests.ps1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
param()

Class ORCACheck
{
    <#

        Check definition

        The checks defined below allow contextual information to be added in to the report HTML document.
        - Control               : A unique identifier that can be used to index the results back to the check
        - Area                  : The area that this check should appear within the report
        - PassText              : The text that should appear in the report when this 'control' passes
        - FailRecommendation    : The text that appears as a title when the 'control' fails. Short, descriptive. E.g "Do this"
        - Importance            : Why this is important
        - ExpandResults         : If we should create a table in the callout which points out which items fail and where
        - ObjectType            : When ExpandResults is set to, For Object, Property Value checks - what is the name of the Object, e.g a Spam Policy
        - ItemName              : When ExpandResults is set to, what does the check return as ConfigItem, for instance, is it a Transport Rule?
        - DataType              : When ExpandResults is set to, what type of data is returned in ConfigData, for instance, is it a Domain?    

    #>

    [Array] $Config=@()
    [String] $Control
    [String] $Area
    [String] $Name
    [String] $PassText
    [String] $FailRecommendation
    [Boolean] $ExpandResults=$false
    [String] $ObjectType
    [String] $ItemName
    [String] $DataType
    [String] $Importance
    [ORCACHI] $ChiValue = [ORCACHI]::NotRated
    [ORCAService]$Services = [ORCAService]::EOP
    [CheckType] $CheckType = [CheckType]::PropertyValue
    $Links
    $ORCAParams
    [Boolean] $SkipInReport=$false

    [ORCAConfigLevel] $AssessmentLevel
    [ORCAResult] $Result=[ORCAResult]::Pass
    [ORCAResult] $ResultStandard=[ORCAResult]::Pass
    [ORCAResult] $ResultStrict=[ORCAResult]::Pass

    [Boolean] $Completed=$false

    [Boolean] $CheckFailed = $false
    [String] $CheckFailureReason = $null
    
    # Overridden by check
    GetResults($Config) { }

    [int] GetCountAtLevelFail([ORCAConfigLevel]$Level)
    {
        if($this.Config.Count -eq 0) { return 0 }
        $ResultsAtLevel = $this.Config.GetLevelResult($Level)
        return @($ResultsAtLevel | Where-Object {$_ -eq [ORCAResult]::Fail}).Count
    }

    [int] GetCountAtLevelPass([ORCAConfigLevel]$Level)
    {
        if($this.Config.Count -eq 0) { return 0 }
        $ResultsAtLevel = $this.Config.GetLevelResult($Level)
        return @($ResultsAtLevel | Where-Object {$_ -eq [ORCAResult]::Pass}).Count
    }

    [int] GetCountAtLevelInfo([ORCAConfigLevel]$Level)
    {
        if($this.Config.Count -eq 0) { return 0 }
        $ResultsAtLevel = $this.Config.GetLevelResult($Level)
        return @($ResultsAtLevel | Where-Object {$_ -eq [ORCAResult]::Informational}).Count
    }

    [ORCAResult] GetLevelResult([ORCAConfigLevel]$Level)
    {

        if($this.GetCountAtLevelFail($Level) -gt 0)
        {
            return [ORCAResult]::Fail
        }

        if($this.GetCountAtLevelPass($Level) -gt 0)
        {
            return [ORCAResult]::Pass
        }

        if($this.GetCountAtLevelInfo($Level) -gt 0)
        {
            return [ORCAResult]::Informational
        }

        return [ORCAResult]::None
    }

    AddConfig([ORCACheckConfig]$Config)
    {
        
        $this.Config += $Config

        $this.ResultStandard = $this.GetLevelResult([ORCAConfigLevel]::Standard)
        $this.ResultStrict = $this.GetLevelResult([ORCAConfigLevel]::Strict)

        if($this.AssessmentLevel -eq [ORCAConfigLevel]::Standard)
        {
            $this.Result = $this.ResultStandard 
        }

        if($this.AssessmentLevel -eq [ORCAConfigLevel]::Strict)
        {
            $this.Result = $this.ResultStrict 
        }

    }

    # Run
    Run($Config)
    {
        Write-Verbose "$(Get-Date) Analysis - $($this.Area) - $($this.Name)"
        
        $this.GetResults($Config)

        If($this.SkipInReport -eq $True)
        {
            Write-Verbose "$(Get-Date) Skipping - $($this.Name) - No longer part of $($this.Area)"
            continue
        }

        # If there is no results to expand, turn off ExpandResults
        if($this.Config.Count -eq 0)
        {
            $this.ExpandResults = $false
        }

        # Set check module to completed
        $this.Completed=$true
    }

}

Class ORCACheckConfig
{

    ORCACheckConfig()
    {
        # Constructor

        $this.Results = @()

        $this.Results += New-Object -TypeName ORCACheckConfigResult -Property @{
            Level=[ORCAConfigLevel]::Standard
        }

        $this.Results += New-Object -TypeName ORCACheckConfigResult -Property @{
            Level=[ORCAConfigLevel]::Strict
        }

        $this.Results += New-Object -TypeName ORCACheckConfigResult -Property @{
            Level=[ORCAConfigLevel]::TooStrict
        }
    }

    # Set the result for this mode
    SetResult([ORCAConfigLevel]$Level,[ORCAResult]$Result)
    {

        $InputResult = $Result;

        # Override level if the config is disabled and result is a failure.
        if(($this.ConfigDisabled -eq $true -or $this.ConfigWontApply -eq $true))
        {
            $InputResult = [ORCAResult]::Informational;

            $this.InfoText = "The policy is not enabled and will not apply. "

            if($InputResult -eq [ORCAResult]::Fail)
            {
                $this.InfoText += "This configuration level is below the recommended settings, and is being flagged incase of accidental enablement. It is not scored as a result of being disabled."
            } else {
                $this.InfoText += "This configuration is set to a recommended level, but is not scored because of the disabled state."
            }
        }

        if($Level -eq [ORCAConfigLevel]::All)
        {
            # Set all to this
            $Rebuilt = @()
            foreach($r in $this.Results)
            {
                $r.Value = $InputResult;
                $Rebuilt += $r
            }
            $this.Results = $Rebuilt
        } elseif($Level -eq [ORCAConfigLevel]::Strict -and $Result -eq [ORCAResult]::Pass)
        {
            # Strict results are pass at standard level too
            ($this.Results | Where-Object {$_.Level -eq [ORCAConfigLevel]::Standard}).Value = [ORCAResult]::Pass
            ($this.Results | Where-Object {$_.Level -eq [ORCAConfigLevel]::Strict}).Value = [ORCAResult]::Pass
        } else {
            ($this.Results | Where-Object {$_.Level -eq $Level}).Value = $InputResult
        }        

        # The level of this configuration should be its strongest result (e.g if its currently standard and we have a strict pass, we should make the level strict)
        if($InputResult -eq [ORCAResult]::Pass -and ($this.Level -lt $Level -or $this.Level -eq [ORCAConfigLevel]::None))
        {
            $this.Level = $Level
        } 
        elseif ($InputResult -eq [ORCAResult]::Fail -and ($Level -eq [ORCAConfigLevel]::Informational -and $this.Level -eq [ORCAConfigLevel]::None))
        {
            $this.Level = $Level
        }

        $this.ResultStandard = $this.GetLevelResult([ORCAConfigLevel]::Standard)
        $this.ResultStrict = $this.GetLevelResult([ORCAConfigLevel]::Strict)

    }

    [ORCAResult] GetLevelResult([ORCAConfigLevel]$Level)
    {

        [ORCAResult]$StrictResult = ($this.Results | Where-Object {$_.Level -eq [ORCAConfigLevel]::Strict}).Value
        [ORCAResult]$StandardResult = ($this.Results | Where-Object {$_.Level -eq [ORCAConfigLevel]::Standard}).Value

        if($Level -eq [ORCAConfigLevel]::Strict)
        {
            return $StrictResult 
        }

        if($Level -eq [ORCAConfigLevel]::Standard)
        {
            # If Strict Level is pass, return that, strict is higher than standard
            if($StrictResult -eq [ORCAResult]::Pass)
            {
                return [ORCAResult]::Pass
            }

            return $StandardResult

        }

        return [ORCAResult]::None
    }

    $Check
    $Object
    $ConfigItem
    $ConfigData
    $ConfigReadonly

    # Config is disabled
    $ConfigDisabled
    # Config will apply, has a rule, not overriden by something
    $ConfigWontApply
    [string]$ConfigPolicyGuid
    $InfoText
    [array]$Results
    [ORCAResult]$ResultStandard
    [ORCAResult]$ResultStrict
    [ORCAConfigLevel]$Level
}

Class ORCACheckConfigResult
{
    [ORCAConfigLevel]$Level=[ORCAConfigLevel]::Standard
    [ORCAResult]$Value=[ORCAResult]::None
}

class PolicyInfo {
    # Policy applies to something - has a rule / not overridden by another policy
    [bool] $Applies

    # Policy is disabled
    [bool] $Disabled

    # Preset policy (Standard or Strict)
    [bool] $Preset

    # Preset level if applicable
    [PresetPolicyLevel] $PresetLevel

    # Built in policy (BIP)
    [bool] $BuiltIn

    # Default policy
    [bool] $Default
    [String] $Name
    [PolicyType] $Type
}

enum CheckType
{
    ObjectPropertyValue
    PropertyValue
}

enum ORCACHI
{
    NotRated = 0
    Low = 5
    Medium = 10
    High = 15
    VeryHigh = 20
    Critical = 100
}

enum ORCAConfigLevel
{
    None = 0
    Standard = 5
    Strict = 10
    TooStrict = 15
    All = 100
}

enum ORCAResult
{
    None = 0
    Pass = 1
    Informational = 2
    Fail = 3
}

[Flags()]
enum ORCAService
{
    EOP = 1
    MDO = 2
}

enum PolicyType
{
    Malware
    Spam
    Antiphish
    SafeAttachments
    SafeLinks
    OutboundSpam
}

enum PresetPolicyLevel
{
    None = 0
    Strict = 1
    Standard = 2
}

# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

<#

179

Checks to determine if SafeLinks is re-wring internal to internal emails. Does not however,
check to determine if there is a rule enforcing this.

#>



class ORCA179 : ORCACheck
{
    <#
    
        CONSTRUCTOR with Check Header Data
    
    #>

    ORCA179()
    {
        $this.Control=179
        $this.Services=[ORCAService]::MDO
        $this.Area="Microsoft Defender for Office 365 Policies"
        $this.Name="Intra-organization Safe Links"
        $this.PassText="Safe Links is enabled intra-organization"
        $this.FailRecommendation="Enable Safe Links between internal users"
        $this.ExpandResults=$True
        $this.ChiValue=[ORCACHI]::High
        $this.Importance="Phishing attacks are not limited from external users. Commonly, when one user is compromised, that user can be used in a process of lateral movement between different accounts in your organization. Configuring Safe Links so that internal messages are also re-written can assist with lateral movement using phishing. The built-in policy is ignored in this check, as it only provides the minimum level of protection."
        $this.ItemName="SafeLinks Policy"
        $this.DataType="Enabled for Internal"
        $this.Links= @{
            "Microsoft 365 Defender Portal - Safe links"="https://security.microsoft.com/safelinksv2"
            "Recommended settings for EOP and Microsoft Defender for Office 365"="https://aka.ms/orca-atpp-docs-7"
        }
    }

    <#
    
        RESULTS
    
    #>

    GetResults($Config)
    {

        $Enabled = $False
        $PolicyCount = 0
      
        ForEach($Policy in $Config["SafeLinksPolicy"]) 
        {
            $IsPolicyDisabled = !$Config["PolicyStates"][$Policy.Guid.ToString()].Applies
            $EnableForInternalSenders = $($Policy.EnableForInternalSenders)

            $PolicyName = $Config["PolicyStates"][$Policy.Guid.ToString()].Name

            if(!$IsPolicyDisabled)
            {
                $PolicyCount++
            }
            

            # Check objects
            $ConfigObject = [ORCACheckConfig]::new()
            $ConfigObject.ConfigItem=$($PolicyName)
            $ConfigObject.ConfigData=$EnableForInternalSenders
            $ConfigObject.ConfigReadonly = $Policy.IsPreset
            $ConfigObject.ConfigDisabled = $Config["PolicyStates"][$Policy.Guid.ToString()].Disabled
            $ConfigObject.ConfigWontApply = !$Config["PolicyStates"][$Policy.Guid.ToString()].Applies
            $ConfigObject.ConfigPolicyGuid=$Policy.Guid.ToString()

            # Determine if MDO link tracking is on for this safelinks policy
            If($EnableForInternalSenders -eq $true) 
            {
                $Enabled = $True
                $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Pass")
            } 
            Else 
            {
                $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Fail")
            }

            $this.AddConfig($ConfigObject)
        }

        If($PolicyCount -eq 0)
        {

            # No policy enabling
            $ConfigObject = [ORCACheckConfig]::new()
            $ConfigObject.ConfigItem="All"
            $ConfigObject.ConfigData="Enabled False"
            $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Fail")

            $this.AddConfig($ConfigObject)

        }    

    }

}
