BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisStrictPresetForPriorityAccount

    # ExchangeOnlineManagement is optional; a stub lets Get-Recipient be mocked when it is not installed.
    if (-not (Get-Command Get-Recipient -ErrorAction SilentlyContinue)) {
        function global:Get-Recipient {
            [CmdletBinding()]
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Identity', Justification = 'Stub signature only; Mock binds -Identity from it.')]
            param([string] $Identity)
        }
        $script:removeRecipientStub = $true
    }

    function New-StrictRule {
        param([hashtable] $Conditions = @{})
        $rule = [ordered]@{
            Identity                  = 'Strict Preset Security Policy'
            State                     = 'Enabled'
            SentTo                    = $null
            SentToMemberOf            = $null
            RecipientDomainIs         = $null
            ExceptIfSentTo            = $null
            ExceptIfSentToMemberOf    = $null
            ExceptIfRecipientDomainIs = $null
        }
        foreach ($key in $Conditions.Keys) { $rule[$key] = $Conditions[$key] }
        [pscustomobject]$rule
    }
}

AfterAll {
    if ($script:removeRecipientStub) {
        Remove-Item -Path Function:\Get-Recipient -ErrorAction SilentlyContinue
    }
}

Describe 'Test-MtCisStrictPresetForPriorityAccount' {
    BeforeEach {
        $script:Result = $null
        $script:Rule = New-StrictRule -Conditions @{ SentToMemberOf = @('Priority Accounts') }
        $script:VipUsers = @(
            [pscustomobject]@{
                Name                      = 'ceo'
                DisplayName               = 'Chief Executive'
                UserPrincipalName         = 'ceo@contoso.com'
                WindowsEmailAddress       = 'ceo@contoso.com'
                ExternalDirectoryObjectId = 'user-ceo'
            }
        )
        $script:Groups = @{ 'user-ceo' = @([pscustomobject]@{ id = 'group-vip'; displayName = 'Priority Accounts'; mail = 'vips@contoso.com'; mailNickname = 'vips' }) }

        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result) $script:Result = $Result }
        Mock -ModuleName Maester Get-MtExo -ParameterFilter { $Request -in 'EOPProtectionPolicyRule', 'ATPProtectionPolicyRule' } { $script:Rule }
        Mock -ModuleName Maester Get-MtExo -ParameterFilter { $Request -eq 'VipUser' } { $script:VipUsers }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            $id = ($RelativeUri -split '/')[1]
            $script:Groups[$id]
        }
        Mock -ModuleName Maester Get-Recipient { $null }
    }

    It 'passes when every priority account is a member of a target group' {
        Test-MtCisStrictPresetForPriorityAccount | Should -BeTrue
        $script:Result | Should -Match '1 of 1'
    }

    It 'resolves SentTo values to the Entra object ID of the priority account' {
        $script:Rule = New-StrictRule -Conditions @{ SentTo = @('Chief Exec Mailbox') }
        Mock -ModuleName Maester Get-Recipient { [pscustomobject]@{ ExternalDirectoryObjectId = 'user-ceo' } } -ParameterFilter { $Identity -eq 'Chief Exec Mailbox' }

        Test-MtCisStrictPresetForPriorityAccount | Should -BeTrue
    }

    It 'includes subdomains of a RecipientDomainIs domain' {
        $script:VipUsers[0].WindowsEmailAddress = 'ceo@exec.contoso.com'
        $script:Rule = New-StrictRule -Conditions @{ RecipientDomainIs = @('contoso.com') }

        Test-MtCisStrictPresetForPriorityAccount | Should -BeTrue
    }

    It 'fails when a priority account matches an exception' {
        $script:Rule = New-StrictRule -Conditions @{ SentToMemberOf = @('Priority Accounts'); ExceptIfSentTo = @('ceo@contoso.com') }

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
        $script:Result | Should -Match 'ceo@contoso.com'
    }

    It 'requires a priority account to meet every recipient condition that is set' {
        $script:Rule = New-StrictRule -Conditions @{ SentTo = @('someone.else@contoso.com'); RecipientDomainIs = @('contoso.com') }

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
    }

    It 'fails when the rule has no recipient conditions' {
        $script:Rule = New-StrictRule

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
        $script:Result | Should -Match 'All recipients \(no conditions\)'
    }

    It 'fails when no priority accounts are tagged' {
        $script:VipUsers = @()

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
        $script:Result | Should -Match 'No users are tagged as priority accounts'
    }

    It 'fails when a rule is disabled' {
        $script:Rule = New-StrictRule -Conditions @{ SentToMemberOf = @('Priority Accounts'); State = 'Disabled' }

        Test-MtCisStrictPresetForPriorityAccount | Should -BeFalse
    }
}
