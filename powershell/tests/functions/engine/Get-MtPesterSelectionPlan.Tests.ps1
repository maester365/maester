BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force

    $script:folder = Join-Path $TestDrive 'pester'
    $null = New-Item -ItemType Directory -Path $script:folder -Force
    @'
Describe 'Sample' -Tag 'Suite', "Quoted" {
    It 'S.1001: plain' -Tag 'S.1001' { $true }
    It 'S.1002: preview' -Tag 'Preview' { $true }
    It 'S.1003: long' -Tag 'LongRunning', 'S.1003' { $true }
    Context 'Inner' -Tag 'Ctx' {
        It 'S.1004: in context' { $true }
    }
    It "S.1005: double quoted" { $true }
    It 'NoColonName' { $true }
    It 'FAM.1.<_>: family' -ForEach @('a', 'b') -Tag "$($_.Dynamic)" { $true }
    It "FAM.2.$($_.Name): family" -ForEach @(@{ Name = 'x' }) { $true }
}
'@ | Set-Content (Join-Path $script:folder 'Sample.Tests.ps1')
    'Describe "Broken" { It "B.1: broken" { ' | Set-Content (Join-Path $script:folder 'Broken.Tests.ps1')

    $script:inventory = InModuleScope Maester -Parameters @{ Folder = $script:folder } { @(Get-MtPesterFileInventory -Path $Folder) }

    function Get-Plan {
        param([hashtable] $Selection = @{}, [object[]] $TestSettings = @())
        InModuleScope Maester -Parameters @{ Inventory = $script:inventory; Selection = $Selection; TestSettings = $TestSettings } {
            $config = Resolve-MtRunConfig -Config @{ Selection = $Selection; TestSettings = $TestSettings }
            $s = Resolve-MtSelection -RunConfig $config
            Get-MtPesterSelectionPlan -Inventory $Inventory -Selection $s -RunConfig $config
        }
    }

    function Get-Reason {
        param($Plan, [string] $Id)
        $row = $script:inventory | Where-Object { $_.Id -eq $Id -or ($_.LiteralPrefix -and $_.LiteralPrefix.StartsWith("$Id.")) } | Select-Object -First 1
        $key = "$($row.File):$($row.Line)"
        if ($Plan.Reasons.Contains($key)) { $Plan.Reasons[$key].ReasonCode } else { $null }
    }
}

Describe 'Get-MtPesterFileInventory' {
    It 'Reads IDs, tags and blocks without running the file' {
        $s1 = $script:inventory | Where-Object Id -EQ 'S.1001'
        $s1.Tags | Should -Be @('Suite', 'Quoted', 'S.1001')
        $s1.Block | Should -Be 'Sample'
        ($script:inventory | Where-Object Id -EQ 'S.1004').Tags | Should -Be @('Suite', 'Quoted', 'Ctx')
        ($script:inventory | Where-Object Id -EQ 'S.1005') | Should -Not -BeNullOrEmpty
    }

    It 'Uses the whole name as the ID when there is no colon' {
        ($script:inventory | Where-Object Name -EQ 'NoColonName').Id | Should -Be 'NoColonName'
    }

    It 'Records names built at run time as families with their literal prefix and no dynamic tags' {
        $fam1 = $script:inventory | Where-Object { $_.LiteralPrefix -eq 'FAM.1.' }
        $fam1.IsStatic | Should -BeFalse
        $fam1.Id | Should -BeNullOrEmpty
        $fam1.HasForEach | Should -BeTrue
        $fam1.Tags | Should -Be @('Suite', 'Quoted')
        ($script:inventory | Where-Object { $_.LiteralPrefix -eq 'FAM.2.' }).IsStatic | Should -BeFalse
    }

    It 'Reports a file that does not parse' {
        ($script:inventory | Where-Object { $_.ParseError -and $_.File -like '*Broken.Tests.ps1' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-MtFamilyParentId' {
    It 'Returns <Expected> for <Prefix>' -ForEach @(
        @{ Prefix = 'MT.1024.'; Expected = 'MT.1024' }
        @{ Prefix = 'MT1060.'; Expected = 'MT1060' }
        @{ Prefix = 'MT.1059.'; Expected = 'MT.1059' }
        @{ Prefix = ''; Expected = $null }
        @{ Prefix = 'Some text '; Expected = $null }
    ) {
        InModuleScope Maester -Parameters @{ Prefix = $Prefix } { Get-MtFamilyParentId -LiteralPrefix $Prefix } | Should -Be $Expected
    }
}

Describe 'Get-MtPesterSelectionPlan' {
    It 'Excludes nothing by default' {
        (Get-Plan).ExcludeLines.Count | Should -Be 0
    }

    It 'Keeps only the named tests with -TestId' {
        $plan = Get-Plan -Selection @{ TestId = @('S.1001') }
        Get-Reason $plan 'S.1001' | Should -BeNullOrEmpty
        Get-Reason $plan 'S.1004' | Should -Be 'NotSelected'
        Get-Reason $plan 'FAM.1' | Should -Be 'NotSelected'
    }

    It 'Matches wildcards case-insensitively' {
        $plan = Get-Plan -Selection @{ TestId = @('s.100*') }
        Get-Reason $plan 'S.1004' | Should -BeNullOrEmpty
        Get-Reason $plan 'NoColonName' | Should -Be 'NotSelected'
    }

    It 'Lets -ExcludeTestId win over -TestId' {
        $plan = Get-Plan -Selection @{ TestId = @('S.*'); ExcludeTestId = @('S.1004') }
        Get-Reason $plan 'S.1004' | Should -Be 'ExcludedById'
    }

    It 'Lifts the Preview exclusion for an exact ID but not for a wildcard' {
        $exact = Get-Plan -Selection @{ TestId = @('S.1002') }
        $exact.LiftPreview | Should -BeTrue
        Get-Reason $exact 'S.1002' | Should -BeNullOrEmpty

        $wild = Get-Plan -Selection @{ TestId = @('S.100*') }
        $wild.LiftPreview | Should -BeFalse
        Get-Reason $wild 'S.1002' | Should -Be 'Preview'
        Get-Reason $wild 'S.1003' | Should -Be 'LongRunning'
    }

    It 'Disables a test with TestSettings Enabled = false and records the reason' {
        $plan = Get-Plan -TestSettings @(@{ Id = 'S.1001'; Enabled = $false; Reason = 'Not for us' })
        Get-Reason $plan 'S.1001' | Should -Be 'DisabledByConfig'
        ($plan.Reasons.Values | Where-Object ReasonCode -EQ 'DisabledByConfig').ReasonDetail | Should -Be 'Not for us'
    }

    It 'Admits only enabled tests with DefaultAction Skip' {
        $plan = Get-Plan -Selection @{ DefaultAction = 'Skip' } -TestSettings @(@{ Id = 'S.1001'; Enabled = $true }, @{ Id = 'S.1004'; Severity = 'High' })
        Get-Reason $plan 'S.1001' | Should -BeNullOrEmpty
        Get-Reason $plan 'S.1004' | Should -Be 'NotListed'
    }

    It 'Selects a family by its parent ID or by one of its instance IDs' {
        Get-Reason (Get-Plan -Selection @{ TestId = @('FAM.1') }) 'FAM.1' | Should -BeNullOrEmpty
        Get-Reason (Get-Plan -Selection @{ TestId = @('FAM.1.a') }) 'FAM.1' | Should -BeNullOrEmpty
        Get-Reason (Get-Plan -Selection @{ TestId = @('FAM.1.*') }) 'FAM.1' | Should -BeNullOrEmpty
    }

    It 'Excludes a whole family only with a pattern that covers every instance' {
        Get-Reason (Get-Plan -Selection @{ ExcludeTestId = @('FAM.1.*') }) 'FAM.1' | Should -Be 'ExcludedById'
        Get-Reason (Get-Plan -Selection @{ ExcludeTestId = @('FAM.1.a') }) 'FAM.1' | Should -BeNullOrEmpty
    }

    It 'Disables a whole family only through a row on its parent ID' {
        Get-Reason (Get-Plan -TestSettings @(@{ Id = 'FAM.1'; Enabled = $false })) 'FAM.1' | Should -Be 'DisabledByConfig'
        # A row for one instance leaves the family running; that instance is marked after the run.
        $plan = Get-Plan -TestSettings @(@{ Id = 'FAM.1.a'; Enabled = $false; Reason = 'Not ours' })
        Get-Reason $plan 'FAM.1' | Should -BeNullOrEmpty
        $plan.DisabledInstances.Keys | Should -Be @('FAM.1.a')
        $plan.DisabledInstances['FAM.1.a'].Reason | Should -Be 'Not ours'
        # A disabled row of an ordinary test is not an instance.
        (Get-Plan -TestSettings @(@{ Id = 'S.1001'; Enabled = $false })).DisabledInstances.Count | Should -Be 0
    }

    It 'Admits a family through a row on its parent or instance ID' {
        Get-Reason (Get-Plan -Selection @{ DefaultAction = 'Skip' } -TestSettings @(@{ Id = 'FAM.1.b'; Enabled = $true })) 'FAM.1' | Should -BeNullOrEmpty
    }

    It 'Lists IDs that match no test, but never wildcards or family instances' {
        $plan = Get-Plan -Selection @{ TestId = @('S.1001', 'NOPE.1', 'NOPE.*', 'FAM.1.zzz') ; ExcludeTestId = @('GONE.1') }
        $plan.UnknownIds | Sort-Object | Should -Be @('GONE.1', 'NOPE.1')
    }
}
