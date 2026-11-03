Describe 'Microsoft Secure Score improvement actions (MT.1264)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test functions are not exported; reach them the same way the agent tests do.
        Use-MtModuleFunction -Name Get-MtSecureScoreControlInstance
        Use-MtModuleFunction -Name Get-MtSecureScoreControlSeverity
        Use-MtModuleFunction -Name ConvertFrom-MtSecureScoreHtml
        Use-MtModuleFunction -Name Test-MtSecureScoreControl

        function Get-FakeControlProfile {
            param([string] $Id, [double] $MaxScore = 5, [string] $Service = 'MDO', [object[]] $StateUpdates = @(), [bool] $Deprecated = $false)
            [pscustomobject]@{
                id                  = $Id
                title               = "Title of $Id"
                maxScore            = $MaxScore
                service             = $Service
                controlCategory     = 'Apps'
                deprecated          = $Deprecated
                remediation         = "Fix $Id"
                remediationImpact   = 'Low'
                actionUrl           = "https://security.microsoft.com/$Id"
                controlStateUpdates = @($StateUpdates)
            }
        }
        function Get-FakeControlScore {
            param([string] $Name, [double] $Score)
            [pscustomobject]@{ controlName = $Name; score = $Score; description = "About $Name"; implementationStatus = 'Status text'; controlCategory = 'Apps' }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:Description = $null
        $script:SkippedBecause = $null
        $script:SkippedCustomReason = $null
        $script:Severity = $null

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $Description, $Severity, $SkippedBecause, $SkippedCustomReason)
            $script:TestResult = $Result
            $script:Description = $Description
            $script:Severity = $Severity
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedCustomReason = $SkippedCustomReason
        }

        # Default tenant: three scored controls; the catalog also holds a control the tenant is not scored on.
        $script:Snapshot = [pscustomobject]@{
            value = @([pscustomobject]@{
                    controlScores = @(
                        (Get-FakeControlScore -Name 'mdo_safelinks' -Score 9),
                        (Get-FakeControlScore -Name 'AdminMFAV2' -Score 0.15),
                        (Get-FakeControlScore -Name 'exo_mailboxaudit' -Score 0)
                    )
                })
        }
        $script:Profiles = @(
            (Get-FakeControlProfile -Id 'mdo_safelinks' -MaxScore 9),
            (Get-FakeControlProfile -Id 'AdminMFAV2' -MaxScore 10 -Service 'AzureAD'),
            (Get-FakeControlProfile -Id 'exo_mailboxaudit' -MaxScore 3 -Service 'EXO'),
            (Get-FakeControlProfile -Id 'mda_okta_unscored' -MaxScore 5 -Service 'MDA_Okta')
        )
        $script:Recommendations = @{ value = @(@{ recommendationType = 'adminMFAV2' }) }

        Mock -ModuleName Maester Invoke-MtGraphRequest { $script:Snapshot } -ParameterFilter { $RelativeUri -eq 'security/secureScores' }
        Mock -ModuleName Maester Invoke-MtGraphRequest { $script:Profiles } -ParameterFilter { $RelativeUri -eq 'security/secureScoreControlProfiles' }
        Mock -ModuleName Maester Invoke-MtGraphRequest { $script:Recommendations } -ParameterFilter { $RelativeUri -like 'directory/recommendations*' }
    }

    AfterEach {
        # Result text must not contain backtick-wrapped code spans (repo result-text lint).
        if ($null -ne $script:TestResult) {
            $script:TestResult | Should -Not -Match '`[^`]+`'
        }
    }

    Context 'Instance source' {
        It 'returns one instance per scored control, not per catalog profile' {
            $instances = @(Get-MtSecureScoreControlInstance)

            $instances.Count | Should -Be 3
            $instances.Id | Should -Not -Contain 'mda_okta_unscored'
            ($instances | Where-Object Id -EQ 'mdo_safelinks').Title | Should -Be 'Title of mdo_safelinks.'
        }

        It 'reads only the latest snapshot, without paging through the history' {
            $null = @(Get-MtSecureScoreControlInstance)

            Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {
                $RelativeUri -eq 'security/secureScores' -and $DisablePaging -and $QueryParameters['$top'] -eq 1
            }
        }

        It 'sets the severity from the maximum points' {
            $instances = @(Get-MtSecureScoreControlInstance)

            ($instances | Where-Object Id -EQ 'AdminMFAV2').Severity | Should -Be 'High'
            ($instances | Where-Object Id -EQ 'mdo_safelinks').Severity | Should -Be 'High'
            ($instances | Where-Object Id -EQ 'exo_mailboxaudit').Severity | Should -Be 'Low'
        }

        It 'tags each instance with the control service and category' {
            $instance = @(Get-MtSecureScoreControlInstance) | Where-Object Id -EQ 'AdminMFAV2'

            $instance.Tag | Should -Contain 'AzureAD'
            $instance.Tag | Should -Contain 'Apps'
        }

        It 'marks a control that is also an Entra recommendation, matching the name without regard to case' {
            $instances = @(Get-MtSecureScoreControlInstance)

            ($instances | Where-Object Id -EQ 'AdminMFAV2').Data.InMt1024 | Should -BeTrue
            ($instances | Where-Object Id -EQ 'exo_mailboxaudit').Data.InMt1024 | Should -BeFalse
        }

        It 'does not mark an AzureAD control that is not an Entra recommendation' {
            $script:Snapshot.value[0].controlScores = @(Get-FakeControlScore -Name 'AATP_AccountWithLeakedCredentials' -Score 5)
            $script:Profiles = @(Get-FakeControlProfile -Id 'AATP_AccountWithLeakedCredentials' -Service 'AzureAD')

            $instance = @(Get-MtSecureScoreControlInstance)[0]

            $instance.Data.InMt1024 | Should -BeFalse
        }

        It 'still returns instances when the Entra recommendations cannot be read' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Forbidden' } -ParameterFilter { $RelativeUri -like 'directory/recommendations*' }

            $instances = @(Get-MtSecureScoreControlInstance)

            $instances.Count | Should -Be 3
            $instances.Data.InMt1024 | Should -Not -Contain $true
        }

        It 'keeps a scored control that has no profile so the test reports it as an error' {
            $script:Profiles = @($script:Profiles | Where-Object id -NE 'exo_mailboxaudit')

            $instances = @(Get-MtSecureScoreControlInstance)

            $instances.Count | Should -Be 3
            $missing = $instances | Where-Object Id -EQ 'exo_mailboxaudit'
            $missing.Data.Profile | Should -BeNullOrEmpty
            { Test-MtSecureScoreControl -Instance $missing } | Should -Throw '*no control profile*'
        }

        It 'skips a deprecated control' {
            $script:Profiles = @($script:Profiles | Where-Object id -NE 'exo_mailboxaudit') + @(Get-FakeControlProfile -Id 'exo_mailboxaudit' -MaxScore 3 -Deprecated $true)

            @(Get-MtSecureScoreControlInstance).Id | Should -Not -Contain 'exo_mailboxaudit'
        }

        It 'returns no instances when the tenant has no snapshot yet' {
            $script:Snapshot = [pscustomobject]@{ value = @() }

            @(Get-MtSecureScoreControlInstance).Count | Should -Be 0
        }

        It 'skips the family as NotAuthorized on a 403 from Graph' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden: Authorization_RequestDenied' } -ParameterFilter { $RelativeUri -eq 'security/secureScores' }

            @(Get-MtSecureScoreControlInstance).Count | Should -Be 0
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'lets an unexpected failure throw so the engine records it as Error' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Service unavailable' } -ParameterFilter { $RelativeUri -eq 'security/secureScores' }

            { Get-MtSecureScoreControlInstance } | Should -Throw '*Service unavailable*'
        }
    }

    Context 'Severity' {
        It 'maps <MaxScore> points to <Expected>' -ForEach @(
            @{ MaxScore = 10; Expected = 'High' }
            @{ MaxScore = 8; Expected = 'High' }
            @{ MaxScore = 7; Expected = 'Medium' }
            @{ MaxScore = 4; Expected = 'Medium' }
            @{ MaxScore = 3; Expected = 'Low' }
            @{ MaxScore = 1; Expected = 'Low' }
        ) {
            Get-MtSecureScoreControlSeverity -MaxScore $MaxScore | Should -Be $Expected
        }
    }

    Context 'HTML conversion' {
        It 'turns links, list items and line breaks into markdown and drops other tags' {
            $html = '<p>Turn it on.<br/>Then <a href="https://contoso.com/x">check it</a>.</p><ul><li>One&nbsp;</li><li>Two</li></ul>'

            $md = ConvertFrom-MtSecureScoreHtml -Html $html

            $md | Should -Match '\[check it\]\(https://contoso.com/x\)'
            $md | Should -Match '(?m)^- One$'
            $md | Should -Match '(?m)^- Two$'
            $md | Should -Not -Match '<[^>]+>'
            $md | Should -Not -Match '&nbsp;'
        }

        It 'returns an empty string for empty input' {
            ConvertFrom-MtSecureScoreHtml -Html '' | Should -Be ''
            ConvertFrom-MtSecureScoreHtml -Html $null | Should -Be ''
        }
    }

    Context 'Test' {
        BeforeEach {
            function Get-FakeInstance {
                param([double] $Score, [double] $MaxScore, [object[]] $StateUpdates = @(), [bool] $InMt1024 = $false)
                [pscustomobject]@{
                    Id       = 'ctrl'
                    Severity = 'Medium'
                    Data     = [pscustomobject]@{
                        ControlScore = (Get-FakeControlScore -Name 'ctrl' -Score $Score)
                        Profile      = (Get-FakeControlProfile -Id 'ctrl' -MaxScore $MaxScore -StateUpdates $StateUpdates)
                        InMt1024     = $InMt1024
                    }
                }
            }
        }

        It 'passes when the control has all of its points' {
            Test-MtSecureScoreControl -Instance (Get-FakeInstance -Score 9 -MaxScore 9) | Should -BeTrue
            $script:TestResult | Should -Match '9 of 9 points'
            $script:TestResult | Should -Not -Match 'Open this improvement action'
            $script:Severity | Should -Be 'Medium'
        }

        It 'fails with the points earned and a link when the control has fewer points' {
            Test-MtSecureScoreControl -Instance (Get-FakeInstance -Score 0.15 -MaxScore 10) | Should -BeFalse
            $script:TestResult | Should -Match '0.15 of 10 points'
            $script:TestResult | Should -Match 'Open this improvement action\]\(https://security.microsoft.com/ctrl\)'
        }

        It 'skips a control marked <State> and reports who set it and their comment' -ForEach @(
            @{ State = 'Ignored'; Label = 'risk accepted' }
            @{ State = 'ThirdParty'; Label = 'resolved through third party' }
            @{ State = 'AlternateMitigation'; Label = 'resolved through alternate mitigation' }
            @{ State = 'Reviewed'; Label = 'reviewed' }
        ) {
            $update = [pscustomobject]@{ state = $State; updatedBy = 'admin@contoso.com'; comment = 'Handled elsewhere'; updatedDateTime = '2026-10-01T00:00:00Z' }

            Test-MtSecureScoreControl -Instance (Get-FakeInstance -Score 0 -MaxScore 5 -StateUpdates @($update)) | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'Custom'
            $script:SkippedCustomReason | Should -Match $Label
            $script:SkippedCustomReason | Should -Match 'admin@contoso.com'
            $script:SkippedCustomReason | Should -Match 'Handled elsewhere'
        }

        It 'does not skip a Planned control, since the work is not done yet' {
            $update = [pscustomobject]@{ state = 'Planned'; updatedBy = 'admin@contoso.com'; comment = $null; updatedDateTime = '2026-10-01T00:00:00Z' }

            Test-MtSecureScoreControl -Instance (Get-FakeInstance -Score 0 -MaxScore 5 -StateUpdates @($update)) | Should -BeFalse
            $script:SkippedBecause | Should -BeNullOrEmpty
        }

        It 'does not skip a control left in the Default state' {
            $update = [pscustomobject]@{ state = 'Default'; updatedBy = $null; comment = $null; updatedDateTime = $null }

            Test-MtSecureScoreControl -Instance (Get-FakeInstance -Score 0 -MaxScore 5 -StateUpdates @($update)) | Should -BeFalse
            $script:SkippedBecause | Should -BeNullOrEmpty
        }

        It 'uses the latest state when the control was set back to Default after being ignored' {
            $updates = @(
                [pscustomobject]@{ state = 'Ignored'; updatedBy = 'admin@contoso.com'; comment = $null; updatedDateTime = '2026-09-01T00:00:00Z' },
                [pscustomobject]@{ state = 'Default'; updatedBy = 'admin@contoso.com'; comment = $null; updatedDateTime = '2026-10-01T00:00:00Z' }
            )

            Test-MtSecureScoreControl -Instance (Get-FakeInstance -Score 0 -MaxScore 5 -StateUpdates $updates) | Should -BeFalse
            $script:SkippedBecause | Should -BeNullOrEmpty
        }

        It 'notes the overlap with MT.1024 only for controls that are Entra recommendations' {
            $null = Test-MtSecureScoreControl -Instance (Get-FakeInstance -Score 0 -MaxScore 5 -InMt1024 $true)
            $script:Description | Should -Match 'MT.1024'

            $null = Test-MtSecureScoreControl -Instance (Get-FakeInstance -Score 0 -MaxScore 5 -InMt1024 $false)
            $script:Description | Should -Not -Match 'MT.1024'
        }
    }
}
