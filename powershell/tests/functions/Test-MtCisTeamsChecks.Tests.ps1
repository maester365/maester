BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisZAP, Test-MtCisThirdPartyFileSharing, Test-MtCisThirdPartyAndCustomApps, Test-MtCisTeamsReportSecurityConcerns

    # MicrosoftTeams is optional; stubs let its cmdlets be mocked when it is not installed.
    $script:stubs = @()
    foreach ($name in 'Get-CsTeamsClientConfiguration', 'Get-CsTeamsMessagingPolicy', 'Get-M365UnifiedTenantSettings', 'Get-CsTeamsSettingsCustomApp', 'Get-CsTenantFederationConfiguration', 'Get-CsExternalAccessPolicy') {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
            Set-Item -Path "function:global:$name" -Value {
                [CmdletBinding()]
                param([string] $Identity)
                $null = $Identity
            }
            $script:stubs += $name
        }
    }

    . "$PSScriptRoot/../../../tests/cis/Test.CIS.M365.8.2.2.ps1"
    . "$PSScriptRoot/../../../tests/cis/Test.CIS.M365.8.2.3.ps1"
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

Describe 'CIS unmanaged Teams user settings' {
    BeforeEach {
        $script:Federation = [pscustomobject]@{
            AllowTeamsConsumer       = $false
            AllowTeamsConsumerInbound = $false
        }
        $script:GlobalPolicy = $null
        Mock Get-CsTenantFederationConfiguration { $script:Federation }
        Mock Get-CsExternalAccessPolicy {
            if ($null -eq $script:GlobalPolicy) { throw 'The Global policy lookup should not run.' }
            $script:GlobalPolicy
        }
    }

    It 'passes 8.2.2 without looking up the Global policy when the organization setting is false' {
        Test-MtCisCommunicateWithUnmanagedTeamsUsers | Should -BeTrue
        Should -Invoke Get-CsExternalAccessPolicy -Times 0 -Exactly
    }

    It 'passes 8.2.3 without looking up the Global policy when the organization setting is false' {
        Test-MtCisCommunicateInitiateExternalTeamsUsers | Should -BeTrue
        Should -Invoke Get-CsExternalAccessPolicy -Times 0 -Exactly
    }

    It 'uses the Global policy fallback for 8.2.2 when the organization setting is enabled' {
        $script:Federation.AllowTeamsConsumer = $true
        $script:GlobalPolicy = [pscustomobject]@{ EnableTeamsConsumerAccess = $false }

        Test-MtCisCommunicateWithUnmanagedTeamsUsers | Should -BeTrue
        Should -Invoke Get-CsExternalAccessPolicy -Times 1 -Exactly
    }

    It 'uses the Global policy fallback for 8.2.3 when the organization setting is enabled' {
        $script:Federation.AllowTeamsConsumerInbound = $true
        $script:GlobalPolicy = [pscustomobject]@{ EnableTeamsConsumerInbound = $false }

        Test-MtCisCommunicateInitiateExternalTeamsUsers | Should -BeTrue
        Should -Invoke Get-CsExternalAccessPolicy -Times 1 -Exactly
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
        $script:SkippedBecause = $null
        $script:TenantSettings = @(
            [pscustomobject]@{ SettingName = 'DefaultApp'; SettingValue = 'All' }
            [pscustomobject]@{ SettingName = 'GlobalApp'; SettingValue = 'None' }
            [pscustomobject]@{ SettingName = 'PrivateApp'; SettingValue = 'None' }
        )
        $script:CustomApp = [pscustomobject]@{ IsSideloadedAppsInteractionEnabled = $false }
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result, $SkippedBecause) $script:Result = $Result; $script:SkippedBecause = $SkippedBecause }
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

    It 'uses Teams settings when the Graph context is app-only' {
        Mock -ModuleName Maester Get-MgContext { [pscustomobject]@{ AuthType = 'AppOnly' } }

        Test-MtCisThirdPartyAndCustomApps | Should -BeTrue
        Should -Invoke Get-M365UnifiedTenantSettings -ModuleName Maester -Times 1 -Exactly
    }

    It 'skips when unified tenant settings reports unsupported app-only authentication' {
        Mock -ModuleName Maester Get-M365UnifiedTenantSettings { throw 'Application-based authentication is not supported for this cmdlet.' }

        Test-MtCisThirdPartyAndCustomApps | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotSupportedAppPermission'
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
            ReportChatMessageAddresses                  = @('soc@contoso.com')
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

    It 'fails when the Teams reporting mailbox is not configured' {
        $script:Policy.ReportChatMessageAddresses = @()

        Test-MtCisTeamsReportSecurityConcerns | Should -BeFalse
        $script:Result | Should -Match 'ReportChatMessageAddresses \| Not set \| soc@contoso.com \| ❌ Fail'
    }

    It 'fails when a reporting destination differs from the single mailbox' {
        $script:Rules[0].SentTo = @('triage@contoso.com')

        Test-MtCisTeamsReportSecurityConcerns | Should -BeFalse
        $script:Result | Should -Match 'Report submission rule \(SentTo\) \| triage@contoso.com \| soc@contoso.com \| ❌ Fail'
    }

    It 'fails when no report submission policy is returned' {
        $script:Policy = $null
        Test-MtCisTeamsReportSecurityConcerns | Should -BeFalse
        $script:Result | Should -Match 'No report submission policy was returned'
    }
}
