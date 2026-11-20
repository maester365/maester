BeforeDiscovery {
    $guideRoot = (Resolve-Path "$PSScriptRoot/../../../tests/ad").Path
    $guideCases = @(Get-ChildItem "$guideRoot/gpo", "$guideRoot/gpo-state" -Filter 'Test.*.md' -File | ForEach-Object {
            @{ GuidePath = $_.FullName; GuideName = $_.Name }
        })
    $checks = @(
        @{ Command = 'Test-MtAdGpoTotalCount'; Investigate = $true; Details = $false }
        @{ Command = 'Test-MtAdGpoStale'; Investigate = $false; Details = $true }
        @{ Command = 'Test-MtAdGpoUnlinkedCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoLinkedCount'; Investigate = $true; Details = $true }
        @{ Command = 'Test-MtCheckADGPOL02'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoUnlinkedTargetCount'; Investigate = $true; Details = $false }
        @{ Command = 'Test-MtAdGpoEnforcedCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoBlockedInheritanceCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoNoPermissionsCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoNoAuthenticatedUsersCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoNoEnterpriseDcCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoNoDomainComputersCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoDenyAceCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoInheritedPermissionsCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoNoApplyGroupPolicyAceCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtCheckADGPOREP12'; Investigate = $true; Details = $false }
        @{ Command = 'Test-MtAdGpoEnforcementCount'; Investigate = $true; Details = $false }
        @{ Command = 'Test-MtAdGpoVersionMismatchCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoCpasswordFoundCount'; Investigate = $false; Details = $false }
        @{ Command = 'Test-MtAdGpoWmiFilterCount'; Investigate = $true; Details = $false }
        @{ Command = 'Test-MtAdGpoSettingsDisabledCount'; Investigate = $true; Details = $false }
        @{ Command = 'Test-MtAdGpoOwnerDistinctCount'; Investigate = $true; Details = $true }
    )
}

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Group Policy guide context' {
    It 'discovers the complete set of Group Policy guides' -ForEach @(@{ DiscoveredCount = $guideCases.Count }) {
        $DiscoveredCount | Should -Be 22
        $paths = Get-ChildItem "$PSScriptRoot/../../../tests/ad/gpo", "$PSScriptRoot/../../../tests/ad/gpo-state" -Filter 'Test.*.md' -File
        $paths.Count | Should -Be 22
    }

    It '<GuideName> retains explanatory context and the results footer' -ForEach $guideCases {
        $text = Get-Content -LiteralPath $GuidePath -Raw
        $text.Split([string[]]@('####'), [System.StringSplitOptions]::None)[0].Trim() | Should -Not -BeNullOrEmpty
        foreach ($heading in 'Control Type', 'Why This Test Matters', 'Security Recommendation', 'How the Test Works', 'Remediation action', 'Related Tests', 'Related links') {
            $pattern = '(?ms)^#### ' + [regex]::Escape($heading) + '\s*\r?\n(?<body>.*?)(?=^#### |\z)'
            $section = [regex]::Match($text, $pattern)
            $section.Success | Should -BeTrue -Because "the guide must explain $heading, not just the result layout"
            $section.Groups['body'].Value.Trim() | Should -Not -BeNullOrEmpty
        }
        [regex]::Matches($text, '<!--- Results --->').Count | Should -Be 1
        $text | Should -Match '<!--- Results --->\s*%TestResult%\s*$'
        $text | Should -Match '\*\*(Detective|Operational)\*\*'
        $ids = @((Get-ChildItem "$PSScriptRoot/../../../tests/ad/gpo", "$PSScriptRoot/../../../tests/ad/gpo-state" -Filter 'Test.*.md' -File).BaseName | ForEach-Object { $_.Substring(5) })
        foreach ($id in [regex]::Matches($text, 'AD-GPO(?:REP|L|S)?-\d+') | ForEach-Object Value) {
            $ids | Should -Contain $id -Because 'related test references must not point at retired IDs'
        }
    }
}

Describe 'Native Group Policy results' {
    BeforeEach {
        $script:detail = $null
        $script:report = [pscustomobject]@{
            Name = 'Policy | <pilot>'
            PermissionsPresent = $true
            HasAuthenticatedUsers = $true
            HasEnterpriseDomainControllers = $true
            HasDomainComputers = $true
            HasDenyAce = $false
            HasInheritedPermissions = $false
            HasApplyGroupPolicyAce = $true
            Enforcement = $false
            HasVersionMismatch = $false
            DirectoryVersion = 1
            SysvolVersion = 1
            CpasswordFound = $false
            DefaultPasswordFound = $false
            Errors = @()
        }
        $linkText = '[LDAP://CN={11111111-1111-1111-1111-111111111111},CN=Policies,DC=example,DC=com;0]'
        $script:state = [pscustomobject]@{
            GPOs = @([pscustomobject]@{
                    Id = '11111111-1111-1111-1111-111111111111'
                    DisplayName = 'Policy | <pilot>'
                    CreationTime = [datetime]'2026-01-01'
                    ModificationTime = [datetime]'2026-01-01'
                    WmiFilter = ''
                    GpoStatus = 3
                    Owner = 'CONTOSO\PolicyOwner'
                })
            GPOReports = @($script:report)
            GPOLinks = @([pscustomobject]@{ GpoGuid = '11111111-1111-1111-1111-111111111111'; GpLink = $linkText; IsDisabled = $false; IsEnforced = $false })
            LinkContainers = @([pscustomobject]@{ ObjectClass = @('organizationalUnit'); DistinguishedName = 'OU=Pilot|test,DC=example,DC=com'; GpLink = $linkText; GpOptions = 0 })
            SiteContainers = @()
        }
        Mock Get-MtADGpoState -ModuleName Maester { $script:state }
        Mock Get-Date -ModuleName Maester { [datetime]'2026-11-19T12:00:00' }
        Mock Add-MtTestResultDetail -ModuleName Maester {
            $script:detail = [pscustomobject]@{ Result = $Result; Investigate = [bool]$Investigate; Skip = $SkippedBecause }
        }
    }

    It '<Command> uses the common layout without empty detail tables' -ForEach $checks {
        InModuleScope Maester -Parameters @{ Command = $Command } { param($Command) & $Command | Should -BeTrue }
        $script:detail.Investigate | Should -Be $Investigate
        $script:detail.Result | Should -Match '\| Metric \| Value \|'
        $script:detail.Result | Should -Not -Match 'GPO Reports'
        ($script:detail.Result -match '#### Details') | Should -Be $Details
        $lines = $script:detail.Result -split '\r?\n'
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\| ---') { $lines[$i + 1] | Should -Match '^\| .+ \|$' -Because 'every table header must be followed by a data row' }
        }
    }

    It 'reports zero disabled links clearly in both shared-helper tests' -ForEach @('Test-MtCheckADGPOL02', 'Test-MtCheckADGPOREP12') {
        InModuleScope Maester -Parameters @{ Command = $_ } { param($Command) & $Command | Should -BeTrue }
        $script:detail.Result | Should -Match 'No disabled GPO links were found. All 1 collected links are enabled'
        $script:detail.Result | Should -Match 'Enabled GPO links \| 1'
        $script:detail.Result | Should -Match 'Disabled GPO links \| 0'
        $script:detail.Result | Should -Not -Match '#### Details|Review 0'
    }

    It 'shows the WMI filter reference and count when a filter is present' {
        $script:state.GPOs[0].WmiFilter = 'Filter | <reference>'
        InModuleScope Maester { Test-MtAdGpoWmiFilterCount | Should -BeTrue }
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Result | Should -Match 'GPOs with WMI filters \| 1'
        $script:detail.Result | Should -Match 'Filter &#124; &lt;reference&gt;'
    }

    It 'counts all disabled categories once and lists readable status labels' {
        $script:state.GPOs = @(0..3 | ForEach-Object { [pscustomobject]@{ DisplayName = "Policy $_"; Id = "id$_"; GpoStatus = $_ } })
        InModuleScope Maester { Test-MtAdGpoSettingsDisabledCount | Should -BeTrue }
        $script:detail.Result | Should -Match 'GPOs with disabled settings \| 3'
        $script:detail.Result | Should -Match 'Only user settings disabled \| 1'
        $script:detail.Result | Should -Match 'Only computer settings disabled \| 1'
        $script:detail.Result | Should -Match 'All settings disabled \| 1'
        $script:detail.Result | Should -Not -Match '\| Policy 3 \|'
    }

    It 'matches named statuses exactly and reports unrecognized statuses as unknown' {
        $script:state.GPOs = @(
            [pscustomobject]@{ DisplayName = 'Named'; Id = 'named'; GpoStatus = 'ComputerDisabled' }
            [pscustomobject]@{ DisplayName = 'Unknown'; Id = 'unknown'; GpoStatus = 'NotComputerDisabled' }
        )
        InModuleScope Maester { Test-MtAdGpoSettingsDisabledCount | Should -BeTrue }
        $script:detail.Result | Should -Match 'GPOs with disabled settings \| 1'
        $script:detail.Result | Should -Match 'GPOs with unknown status \| 1'
        $script:detail.Result | Should -Match 'Unknown \| unknown \| Unknown'
    }

    It 'lists unresolved owners without counting them as known owners' {
        $script:state.GPOs += [pscustomobject]@{ DisplayName = 'Unreadable | GPO'; Owner = $null }
        InModuleScope Maester { Test-MtAdGpoOwnerDistinctCount | Should -BeTrue }
        $script:detail.Result | Should -Match 'Distinct known owners \| 1'
        $script:detail.Result | Should -Match 'GPOs with unknown owners \| 1'
        $script:detail.Result | Should -Match 'Unknown \| 1 \| Unreadable &#124; GPO'
    }

    It 'does not treat an unknown alternative computer-access principal as clean' -ForEach @(
        @{ Computers = $false; Authenticated = $null; Expected = $true; Investigate = $true; Details = $true }
        @{ Computers = $false; Authenticated = $false; Expected = $false; Investigate = $false; Details = $true }
        @{ Computers = $false; Authenticated = $true; Expected = $true; Investigate = $false; Details = $false }
        @{ Computers = $null; Authenticated = $true; Expected = $true; Investigate = $false; Details = $false }
    ) {
        $script:state.GPOReports += [pscustomobject]@{ Name = 'Alternative | GPO'; HasDomainComputers = $Computers; HasAuthenticatedUsers = $Authenticated }
        InModuleScope Maester -Parameters @{ Expected = $Expected } { param($Expected) Test-MtAdGpoNoDomainComputersCount | Should -Be $Expected }
        $script:detail.Investigate | Should -Be $Investigate
        ($script:detail.Result -match '#### Details') | Should -Be $Details
        if ($Investigate) { $script:detail.Result | Should -Match 'Alternative &#124; GPO \| Unknown' }
    }

    It 'fails enforced links and lists the affected container' {
        $script:state.GPOLinks[0].IsEnforced = $true
        $script:state.GPOLinks[0] | Add-Member -NotePropertyName DistinguishedName -NotePropertyValue 'OU=Pilot|test,DC=example,DC=com'
        InModuleScope Maester { Test-MtAdGpoEnforcedCount | Should -BeFalse }
        $script:detail.Result | Should -Match 'Enforced GPO links \| 1'
        $script:detail.Result | Should -Match 'OU=Pilot&#124;test'
    }

    It 'does not count disabled links as enabled links' {
        $script:state.GPOLinks[0].IsDisabled = $true
        InModuleScope Maester { Test-MtAdGpoLinkedCount | Should -BeTrue }
        $script:detail.Result | Should -Match 'GPOs with enabled links \| 0'
        $script:detail.Result | Should -Not -Match '#### Details'
    }

    It 'errors rather than reporting zero when link collection failed' -ForEach @('Test-MtAdGpoLinkedCount', 'Test-MtAdGpoEnforcedCount') {
        $script:state.GPOLinks = $null
        InModuleScope Maester -Parameters @{ Command = $_ } { param($Command) { & $Command } | Should -Throw '*could not be collected*' }
    }

    It 'does not treat unknown enforcement as zero in the GPO inventory' {
        $script:state.GPOLinks[0].IsEnforced = $null
        InModuleScope Maester { Test-MtAdGpoEnforcementCount | Should -BeTrue }
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Result | Should -Match 'GPOs with unknown enforcement \| 1'
        $script:detail.Result | Should -Match 'Policy &#124; &lt;pilot&gt; \| Unknown'
        $script:detail.Result | Should -Not -Match 'No collected GPO has an enforced link'
    }

    It 'treats unlinked GPOs as known unenforced when link collection succeeded' {
        $script:state.GPOLinks = @()
        $script:report.Enforcement = $null
        InModuleScope Maester { Test-MtAdGpoEnforcementCount | Should -BeTrue }
        $script:detail.Result | Should -Match 'GPOs with unknown enforcement \| 0'
        $script:detail.Result | Should -Match 'No collected GPO has an enforced link'
        $script:detail.Result | Should -Not -Match '#### Details'
    }

    It 'keeps enforcement unknown when link collection failed' {
        $script:state.GPOLinks = $null
        InModuleScope Maester { Test-MtAdGpoEnforcementCount | Should -BeTrue }
        $script:detail.Result | Should -Match 'GPOs with unknown enforcement \| 1'
        $script:detail.Result | Should -Match 'could not be determined for any collected GPO'
        $script:detail.Result | Should -Not -Match 'No enforced links were found among evaluated GPOs'
        $script:detail.Result | Should -Match '#### Details'
    }

    It 'does not imply evaluated settings when every GPO status is unknown' {
        $script:state.GPOs[0].GpoStatus = $null
        InModuleScope Maester { Test-MtAdGpoSettingsDisabledCount | Should -BeTrue }
        $script:detail.Result | Should -Match 'Settings status could not be determined for any collected GPO'
        $script:detail.Result | Should -Match 'GPOs with unknown status \| 1'
    }

    It 'counts each GPO once even when several of its links are enforced' {
        $script:state.GPOLinks[0].IsEnforced = $true
        $script:state.GPOLinks += $script:state.GPOLinks[0].PSObject.Copy()
        InModuleScope Maester { Test-MtAdGpoEnforcementCount | Should -BeTrue }
        $script:detail.Result | Should -Match 'GPOs with enforced links \| 1'
    }

    It 'fails blocked inheritance and errors on missing containers' {
        $script:state.LinkContainers[0].GpOptions = 1
        InModuleScope Maester { Test-MtAdGpoBlockedInheritanceCount | Should -BeFalse }
        $script:detail.Result | Should -Match 'OU=Pilot&#124;test'
        $script:state.LinkContainers = $null
        InModuleScope Maester { { Test-MtAdGpoBlockedInheritanceCount } | Should -Throw '*cannot be assessed*' }
    }

    It 'does not mistake a settings-status label for proof that a linked GPO is unlinked' {
        $script:state.GPOs[0].GpoStatus = 'Unlinked'
        InModuleScope Maester { Test-MtAdGpoUnlinkedCount | Should -BeTrue }
    }
}

Describe 'Group Policy result layout' {
    It 'renders zero metrics without an empty detail table' {
        InModuleScope Maester {
            $result = Format-MtAdGpoResult -Summary 'No disabled links found.' -Metrics ([ordered]@{ 'Total links' = 2; 'Disabled links' = 0 }) -Details @() -Properties Name
            $result | Should -Match 'No disabled links found'
            $result | Should -Match 'Disabled links \| 0'
            $result | Should -Not -Match '#### Details|\| Name \|'
        }
    }

    It 'renders one consistent non-empty detail table and escapes every cell' {
        InModuleScope Maester {
            $result = Format-MtAdGpoResult -Summary 'Review one policy.' -Metrics ([ordered]@{ 'Total GPOs' = 1 }) -Details @([pscustomobject]@{ Name = "Policy | <test>`nsecond line"; Flag = $false }) -Properties Name, Flag -Headers GPO, Finding
            $result | Should -Match '#### Details'
            $result | Should -Match '\| GPO \| Finding \|'
            $result | Should -Match 'Policy &#124; &lt;test&gt; second line \| False'
        }
    }

    It 'distinguishes unknown values from zero and false' {
        InModuleScope Maester {
            $result = Format-MtAdGpoResult -Summary 'Review collection.' -Metrics ([ordered]@{ Known = 0; Unknown = $null }) -Details @([pscustomobject]@{ Name = 'Policy'; Unknown = $null }) -Properties Name, Unknown
            $result | Should -Match 'Known \| 0'
            $result | Should -Match 'Unknown \| Unknown'
            $result | Should -Match 'Policy \| Unknown'
        }
    }
}
