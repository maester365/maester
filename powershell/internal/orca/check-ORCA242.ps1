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



class ORCA242 : ORCACheck
{
    <#
    
        Check for first contact safety tip
    
    #>

    ORCA242()
    {
        $this.Control=242
        $this.Services=[ORCAService]::MDO
        $this.Area="Microsoft Defender for Office 365 Alerts"
        $this.Name="Protection Alerts"
        $this.PassText="Important protection alerts responsible for AIR activities are enabled"
        $this.FailRecommendation="Enable important protection alerts that are responsible for AIR activities."
        $this.Importance="Automated Incident Response (AIR) triggers off certain alerts that fire in the environment. AIR is responsible for detecting further anomalies and providing automated remediation actions designed to mitigate threats/attacks. It is important that these alerts are enabled so that AIR can function correctly."
        $this.ExpandResults=$True
        $this.CheckType=[CheckType]::ObjectPropertyValue
        $this.ObjectType="Protection Alert"
        $this.ItemName="Setting"
        $this.DataType="Current Value"
        $this.ChiValue=[ORCACHI]::Critical
        $this.Links= @{
            "Automated investigation and response in Microsoft 365 Defender"="https://learn.microsoft.com/en-us/microsoft-365/security/defender/m365d-autoir"
        }
    }

    <#
    
        RESULTS
    
    #>

    GetResults($Config)
    {

        $ImportantAlerts = @(
            "A potentially malicious URL click was detected",
            "Teams message reported by user as security risk",
            "Email messages containing phish URLs removed after delivery",
            "Suspicious Email Forwarding Activity",
            "Malware not zapped because ZAP is disabled",
            "Phish delivered due to an ETR override",
            "Email messages containing malicious file removed after delivery",
            "Email reported by user as malware or phish",
            "Email messages containing malicious URL removed after delivery",
            "Email messages containing malware removed after delivery",
            "A user clicked through to a potentially malicious URL",
            "Email messages from a campaign removed after delivery",
            "Email messages removed after delivery",
            "Suspicious email sending patterns detected"
        )

        if($Config.ContainsKey('ProtectionAlert'))
        {
            ForEach ($ImportantAlert in $ImportantAlerts)
            {
                $FoundAlert = $Config["ProtectionAlert"] | Where-Object {$_.Name -eq $ImportantAlert}

                # These alerts cannot be removed, so if it's $null, then the alert isnt deployed to this tenant, so we dont want
                # to flag them at all.

                if($null -ne $FoundAlert)
                {
                    $ConfigObject = [ORCACheckConfig]::new()
                    $ConfigObject.Object=$ImportantAlert
                    $ConfigObject.ConfigItem="Disabled"
                    $ConfigObject.ConfigData=$FoundAlert.Disabled

                    if($FoundAlert.Disabled)
                    {
                        $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Fail")
                    } 
                    else 
                    {
                        $ConfigObject.SetResult([ORCAConfigLevel]::Standard,"Pass")
                    }

                    $this.AddConfig($ConfigObject)
                }
            }

        }

    }

}
