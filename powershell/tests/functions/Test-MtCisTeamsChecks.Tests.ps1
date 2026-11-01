BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisZAP, Test-MtCisThirdPartyFileSharing, Test-MtCisThirdPartyAndCustomApps, Test-MtCisTeamsReportSecurityConcerns

    # MicrosoftTeams is optional; stubs let its cmdlets be mocked when it is not installed.
    $script:stubs = @()
    foreach ($name in 'Get-CsTeamsClientConfiguration', 'Get-CsTeamsMessagingPolicy', 'Get-M365UnifiedTenantSettings', 'Get-CsTeamsSettingsCustomApp') {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
            Set-Item -Path "function:global:$name" -Value {
                [CmdletBinding()]
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Identity', Justification = 'Stub signature only; Mock binds -Identity from it.')]
                param([string] $Identity)
            }
            $script:stubs += $name
        }
    }
}

AfterAll {
    foreach ($name in $script:stubs) {
        Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue
    }
}

Describe 'Test-MtCisZAP' {
    BeforeEach {
        $script:Result = $null
        $script:Policies = @([pscustomobject]@{ Name = 'Teams Protection Policy'; ZapEnabled = $true })
        $script:Rules = @()
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result) $script:Result = $Result }
        Mock -ModuleName Maester Get-MtExo -ParameterFilter { $Request -eq 'TeamsProtectionPolicy' } { $script:Policies }
        Mock -ModuleName Maester Get-MtExo -ParameterFilter { $Request -eq 'TeamsProtectionPolicyRule' } { $script:Rules }
    }

    It 'passes when ZAP is on' {
        Test-MtCisZAP | Should -BeTrue
        $script:Result | Should -Match 'No participants are excluded'
    }

    It 'fails when ZAP is off' {
        $script:Policies[0].ZapEnabled = $false
        Test-MtCisZAP | Should -BeFalse
    }

    It 'fails when no Teams protection policy is returned' {
        $script:Policies = @()
        Test-MtCisZAP | Should -BeFalse
        $script:Result | Should -Match 'No Teams protection policy was returned'
    }

    It 'lists the exclusions for review' {
        $script:Rules = @([pscustomobject]@{ ExceptIfSentTo = @('research@contoso.com'); ExceptIfSentToMemberOf = $null; ExceptIfRecipientDomainIs = @('research.contoso.com') })
        Test-MtCisZAP | Should -BeTrue
        $script:Result | Should -Match 'ExceptIfSentTo \| research@contoso.com'
        $script:Result | Should -Match 'ExceptIfRecipientDomainIs \| research.contoso.com'
    }
}

Describe 'Test-MtCisThirdPartyFileSharing' {
    BeforeEach {
        $script:Result = $null
        $script:Config = [pscustomobject]@{ AllowDropBox = $false; AllowBox = $false; AllowGoogleDrive = $false; AllowShareFile = $false; AllowEgnyte = $false }
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result) $script:Result = $Result }
        Mock -ModuleName Maester Get-CsTeamsClientConfiguration { $script:Config }
    }

    It 'passes when every provider is off' {
        Test-MtCisThirdPartyFileSharing | Should -BeTrue
    }

    It 'fails when a provider that is not approved is on' {
        $script:Config.AllowBox = $true
        Test-MtCisThirdPartyFileSharing | Should -BeFalse
    }

    It 'passes when only approved providers are on' {
        $script:Config.AllowBox = $true
        Test-MtCisThirdPartyFileSharing -ApprovedProviders Box | Should -BeTrue
    }

    It 'fails when the client configuration is not returned' {
        $script:Config = $null
        Test-MtCisThirdPartyFileSharing | Should -BeFalse
    }
}

Describe 'Test-MtCisThirdPartyAndCustomApps' {
    BeforeEach {
        $script:Result = $null
        $script:TenantSettings = @(
            [pscustomobject]@{ SettingName = 'DefaultApp'; SettingValue = 'All' }
            [pscustomobject]@{ SettingName = 'GlobalApp'; SettingValue = 'None' }
            [pscustomobject]@{ SettingName = 'PrivateApp'; SettingValue = 'None' }
        )
        $script:CustomApp = [pscustomobject]@{ IsSideloadedAppsInteractionEnabled = $false }
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result) $script:Result = $Result }
        Mock -ModuleName Maester Get-M365UnifiedTenantSettings { $script:TenantSettings }
        Mock -ModuleName Maester Get-CsTeamsSettingsCustomApp { $script:CustomApp }
    }

    It 'passes when third-party apps, custom apps and custom apps in preview are off' {
        Test-MtCisThirdPartyAndCustomApps | Should -BeTrue
    }

    It 'fails when third-party apps are available by default' {
        $script:TenantSettings[1].SettingValue = 'All'
        Test-MtCisThirdPartyAndCustomApps | Should -BeFalse
    }

    It 'fails when users can interact with custom apps in preview' {
        $script:CustomApp.IsSideloadedAppsInteractionEnabled = $true
        Test-MtCisThirdPartyAndCustomApps | Should -BeFalse
    }

    It 'fails when the settings are not returned' {
        $script:TenantSettings = @()
        $script:CustomApp = $null
        Test-MtCisThirdPartyAndCustomApps | Should -BeFalse
        $script:Result | Should -Match 'Not found'
    }
}

Describe 'Test-MtCisTeamsReportSecurityConcerns' {
    BeforeEach {
        $script:Result = $null
        $script:MessagingPolicy = [pscustomobject]@{ AllowSecurityEndUserReporting = $true }
        $script:Policy = [pscustomobject]@{
            EnableReportToMicrosoft                     = $false
            ReportChatMessageEnabled                    = $false
            ReportChatMessageToCustomizedAddressEnabled = $true
            ReportJunkToCustomizedAddress               = $true
            ReportNotJunkToCustomizedAddress            = $true
            ReportPhishToCustomizedAddress              = $true
            ReportJunkAddresses                         = @('soc@contoso.com')
            ReportNotJunkAddresses                      = @('soc@contoso.com')
            ReportPhishAddresses                        = @('soc@contoso.com')
        }
        $script:Rules = @([pscustomobject]@{ Name = 'DefaultReportSubmissionRule'; State = 'Enabled'; SentTo = @('soc@contoso.com') })
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result) $script:Result = $Result }
        Mock -ModuleName Maester Get-CsTeamsMessagingPolicy { $script:MessagingPolicy }
        Mock -ModuleName Maester Get-MtExo -ParameterFilter { $Request -eq 'ReportSubmissionPolicy' } { $script:Policy }
        Mock -ModuleName Maester Get-MtExo -ParameterFilter { $Request -eq 'ReportSubmissionRule' } { $script:Rules }
    }

    It 'passes when reports go only to the reporting mailbox' {
        Test-MtCisTeamsReportSecurityConcerns | Should -BeTrue
    }

    It 'fails when reported messages are also sent to Microsoft' {
        $script:Policy.EnableReportToMicrosoft = $true
        Test-MtCisTeamsReportSecurityConcerns | Should -BeFalse
        $script:Result | Should -Match 'EnableReportToMicrosoft \| True \| False \| ❌ Fail'
    }

    It 'fails when the report submission rule is missing or disabled' {
        $script:Rules = @([pscustomobject]@{ Name = 'DefaultReportSubmissionRule'; State = 'Disabled'; SentTo = @('soc@contoso.com') })
        Test-MtCisTeamsReportSecurityConcerns | Should -BeFalse

        $script:Rules = @()
        Test-MtCisTeamsReportSecurityConcerns | Should -BeFalse
    }

    It 'fails when Teams reporting is not set' {
        $script:MessagingPolicy = [pscustomobject]@{ AllowSecurityEndUserReporting = $null }
        Test-MtCisTeamsReportSecurityConcerns | Should -BeFalse
    }

    It 'fails when no report submission policy is returned' {
        $script:Policy = $null
        Test-MtCisTeamsReportSecurityConcerns | Should -BeFalse
        $script:Result | Should -Match 'No report submission policy was returned'
    }
}
