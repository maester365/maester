BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}
Describe 'Tenant-controlled names in security check reports' {
    BeforeEach {
        $script:captured=$null
        Mock Add-MtTestResultDetail -ModuleName Maester { $script:captured=$Result }
    }
    It 'preserves literal replacement tokens in a CIS policy name' {
        $script:policy=[pscustomobject]@{
            id='policy';displayName='Policy $& $$';state='enabled'
            conditions=@{users=@{includeUsers=@('All')};applications=@{includeApplications=@('All');excludeApplications=@()};clientAppTypes=@('all');userRiskLevels=@();signInRiskLevels=@()}
            grantControls=@{operator='OR';builtInControls=@('mfa');authenticationStrength=$null;termsOfUse=@();customAuthenticationFactors=@()}
        }
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester {$script:policy}
        & (Get-Module Maester) { Test-MtCisMfaForEveryUser }|Should -BeTrue
        $script:captured|Should -Match ([regex]::Escape('Policy $& $$'))
    }
    It 'keeps a named location containing a pipe inside one cell' {
        Mock Invoke-MtGraphRequest -ModuleName Maester {
            [pscustomobject]@{'@odata.type'='#microsoft.graph.ipNamedLocation';displayName='HQ | Berlin $& $$';isTrusted=$true;ipRanges=@(@{cidrAddress='10.0.0.0/24'})}
        }
        & (Get-Module Maester) { Test-MtCisTrustedNamedLocation }|Should -BeTrue
        $script:captured | Should -Match ([regex]::Escape('HQ \| Berlin $& $$'))
        $lines=@($script:captured -split "`n"|Where-Object {$_.StartsWith('|')})
        ([regex]::Split($lines[2],'(?<!\\)\|')).Count|Should -Be ([regex]::Split($lines[0],'(?<!\\)\|')).Count
    }
    It 'keeps an anti-spam policy containing a pipe inside one cell' {
        Mock Get-MtExo -ModuleName Maester {[pscustomobject]@{Identity='Policy | East $& $$';AllowedSenderDomains=@('example.org')}}
        & (Get-Module Maester) { Test-MtCisAntiSpamAllowedDomain }|Should -BeFalse
        $script:captured | Should -Match ([regex]::Escape('Policy \| East $& $$'))
        $lines=@($script:captured -split "`n"|Where-Object {$_.StartsWith('|')})
        ([regex]::Split($lines[2],'(?<!\\)\|')).Count|Should -Be ([regex]::Split($lines[0],'(?<!\\)\|')).Count
    }
    It 'escapes a closing bracket in the baseline placeholder app link' {
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester {@()}
        Mock Invoke-MtGraphRequest -ModuleName Maester {
            if($RelativeUri -eq 'identity/conditionalAccess/settings'){
                [pscustomobject]@{advancedSettings=@{baselineScopes=@{resourceAppId='7c9e6f2a-4b1d-4e8a-9f3c-b5d2a8e1c4f7'}}}
            }elseif($RelativeUri -eq 'servicePrincipals'){
                [pscustomobject]@{id='sp-id';displayName='Placeholder] suffix'}
            }else{throw "Unexpected endpoint: $RelativeUri"}
        }
        & (Get-Module Maester) { Test-MtCaBaselineScopesEnforcement }|Should -BeTrue
        $script:captured|Should -Match ([regex]::Escape('[Placeholder\] suffix]('))
    }
    It 'keeps a multiline authentication-strength name inside its table cell' {
        $script:managed=[pscustomobject]@{
            id='managed';displayName='Microsoft-managed: Example';state='enabledForReportingButNotEnforced';createdDateTime=(Get-Date).AddDays(-5)
            grantControls=@{builtInControls=@();operator='OR';authenticationStrength=@{displayName="Strong | [Key]`nMFA"}}
        }
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester {$script:managed}
        Mock Get-GraphObjectMarkdown -ModuleName Maester {'policy-link'}
        & (Get-Module Maester) { Test-MtCaMicrosoftManagedPolicyReportOnly }|Should -BeFalse
        $script:captured | Should -Match ([regex]::Escape('authentication strength: Strong \| \[Key\] MFA'))
        $lines=@($script:captured -split "`n"|Where-Object {$_.StartsWith('|')})
        ([regex]::Split($lines[2],'(?<!\\)\|')).Count|Should -Be ([regex]::Split($lines[0],'(?<!\\)\|')).Count
    }
}

Describe 'Affected-object matching with escaped display names' {
    It 'preserves IDs and duplicate names for <Name>' -ForEach @(
        @{ Name = 'Same name' }
        @{ Name = 'Rule ] review' }
        @{ Name = '[outer [inner] tail]' }
        @{ Name = 'Back\slash [review] ]' }
        @{ Name = 'Policy $& $$' }
    ) {
        $ids = @('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222')
        $label = Get-MtSafeMarkdown $Name
        $markdown = ($ids | ForEach-Object { "[$label](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$_)" }) -join "`n"
        $records = @(& (Get-Module Maester) { param($md) Get-MtAffectedObjectFromMarkdown -Markdown $md -TestId 'PROBE.1' } $markdown)
        $records | Should -HaveCount 2
        @($records.Id | Sort-Object) | Should -Be $ids
        foreach ($record in $records) {
            $record.Type | Should -Be 'ConditionalAccessPolicy'
            $record.DisplayName | Should -BeExactly $Name
            $record.TestId | Should -Be 'PROBE.1'
        }
    }
}
