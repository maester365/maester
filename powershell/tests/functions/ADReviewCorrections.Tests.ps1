BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'AD review corrections preserve native report outcomes' {
    It 'generates HTML and JSON after thrown errors, explicit errors and Investigate results' {
        $folder = Join-Path $TestDrive 'native-review'
        $output = Join-Path $TestDrive 'report-review'
        $null = New-Item -ItemType Directory -Path $folder -Force
        $bodies = @{
            1 = 'throw ''Computer inventory is unavailable.'''
            2 = 'Add-MtTestResultDetail -SkippedBecause Error -Result ''User inventory is unavailable.''; return'
            3 = 'Add-MtTestResultDetail -Investigate -Result ''Visible inventory needs review.''; return $false'
        }
        foreach ($number in 1..3) {
            @"
function Test-Review$number {
    [MaesterTest(Id = 'REVIEW.$number', Title = 'Review outcome $number', Service = 'None')]
    [CmdletBinding()]
    param()
    $($bodies[$number])
}
"@ | Set-Content (Join-Path $folder "Test.REVIEW.$number.ps1")
            "Review outcome.`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $folder "Test.REVIEW.$number.md")
        }
        $manifest = (Resolve-Path "$PSScriptRoot/../../Maester.psd1").Path
        $null = pwsh -NoProfile -NonInteractive -Command "Import-Module '$manifest' -WarningAction SilentlyContinue; Invoke-Maester -Path '$folder' -SkipBuiltIn -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputFolder '$output' -OutputFolderFileName review" 2>&1
        $LASTEXITCODE | Should -Be 0
        $json = @(Get-ChildItem $output -Filter '*.json')
        $html = @(Get-ChildItem $output -Filter '*.html')
        $json.Count | Should -Be 1
        $html.Count | Should -Be 1
        $results = Get-Content $json[0].FullName -Raw | ConvertFrom-Json
        ($results.Tests | Where-Object Id -EQ 'REVIEW.1').Result | Should -Be 'Error'
        ($results.Tests | Where-Object Id -EQ 'REVIEW.2').Result | Should -Be 'Error'
        ($results.Tests | Where-Object Id -EQ 'REVIEW.3').Result | Should -Be 'Investigate'
        (Get-Content $html[0].FullName -Raw) | Should -Match 'maester-report-data'
    }
}

Describe 'AD missing inventory and preserved result context' {
    BeforeEach {
        $script:state = [pscustomobject]@{
            Computers = @()
            Users = @()
            Forest = [pscustomobject]@{ Name = 'example.com'; ForestMode = 'Windows2016Forest' }
            OptionalFeatures = @([pscustomobject]@{ Name = 'Recycle Bin Feature'; IsEnabled = $true; EnabledScopes = @('CN=Partitions,CN=Configuration,DC=example,DC=com') })
        }
        $script:gpoState = [pscustomobject]@{ GPOLinks = $null; LinkContainers = $null }
        $script:detail = ''
        Mock -ModuleName Maester Get-MtADDomainState { $script:state }
        Mock -ModuleName Maester Get-MtADGpoState { $script:gpoState }
        Mock -ModuleName Maester Add-MtTestResultDetail { $script:detail = $Result }
    }
    It 'reports an empty visible computer collection as inventory rather than a connection failure' {
        InModuleScope Maester { Test-MtAdComputerDisabledCount | Should -BeTrue }
        $script:detail | Should -Match 'Total Computers \| 0'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }
    It 'ends unavailable computer inventory using the native explicit-error convention' {
        $script:state.Computers = $null
        InModuleScope Maester { Test-MtAdComputerDisabledCount | Should -BeNullOrEmpty }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Error' }
    }

    It 'reports partial enabled-state inventory without counting unknown computers as enabled' {
        $script:state.Computers = @(
            [pscustomobject]@{ Name = 'disabled'; Enabled = $false; DistinguishedName = 'CN=disabled,DC=example,DC=com' }
            [pscustomobject]@{ Name = 'enabled'; Enabled = $true; DistinguishedName = 'CN=enabled,DC=example,DC=com' }
            [pscustomobject]@{ Name = 'unknown'; Enabled = $null; DistinguishedName = 'CN=unknown,DC=example,DC=com' }
        )
        InModuleScope Maester { Test-MtAdComputerDisabledCount | Should -BeTrue }
        $script:detail | Should -Match 'Enabled Computers \| 1'
        $script:detail | Should -Match 'Disabled Computers \| 1'
        $script:detail | Should -Match 'Unknown Enabled State \| 1'
        $script:detail | Should -Match '\| disabled \| CN=disabled'
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
        Should -Not -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $SkippedBecause -eq 'Error' }
    }
    It 'does not turn missing GPO link data into clean enforced or inheritance-blocking assessments' {
        InModuleScope Maester {
            Test-MtAdGpoEnforcedCount | Should -BeNullOrEmpty
            Test-MtAdGpoBlockedInheritanceCount | Should -BeNullOrEmpty
        }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 2 -Exactly -ParameterFilter { $SkippedBecause -eq 'Error' }
    }
    It 'investigates enforced links instead of failing an informational inventory' {
        $script:gpoState.GPOLinks = @([pscustomobject]@{ Enforced = $true })
        InModuleScope Maester { Test-MtAdGpoEnforcedCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
        $script:detail | Should -Match 'Enforced GPO link entries \| 1'
        $script:detail | Should -Not -Match 'inheritance-blocking links'
    }
    It 'retains Recycle Bin forest functional level, scopes and status for both outcomes' {
        InModuleScope Maester { Test-MtAdRecycleBinStatus | Should -BeTrue }
        $script:detail | Should -Match 'Forest functional level \| Windows2016Forest'
        $script:detail | Should -Match 'Enabled scopes \| CN=Partitions'
        $script:detail | Should -Match 'Status \| Enabled'
        $script:state.OptionalFeatures[0].IsEnabled = $false
        InModuleScope Maester { Test-MtAdRecycleBinStatus | Should -BeFalse }
        $script:detail | Should -Match 'Status \| Not enabled'
        $script:detail | Should -Match 'irreversible'
    }
    It 'rates Recycle Bin low and marks complete member scans as long running' {
        $test = Get-MtTest AD-FOR-04
        $test.Severity | Should -Be 'Low'
        $test.ImplementationCost | Should -Be 'Low'
        foreach ($id in 'AD-GMC-01', 'AD-GMC-02', 'AD-GMC-04', 'AD-GMC-06', 'AD-GMC-08') {
            (Get-MtTest $id).LongRunning | Should -BeTrue -Because $id
        }
        $versionCheck = Get-MtTest AD-GPOREP-15
        $versionCheck.Severity | Should -Be 'Low'
        @(Get-MtTest -Tag AD-GPOREP-16).Id | Should -Contain 'AD-GPOREP-15'
    }
    It 'classifies group parent components without treating every group CN as a container' {
        $script:state | Add-Member -NotePropertyName Groups -NotePropertyValue @(
            [pscustomobject]@{ DistinguishedName = 'CN=An\, escaped group,OU=Teams,DC=example,DC=com' }
            [pscustomobject]@{ DistinguishedName = 'CN=Another,CN=Users,DC=example,DC=com' }
            [pscustomobject]@{ DistinguishedName = 'CN=AtRoot,DC=example,DC=com' }
        )
        InModuleScope Maester { Test-MtAdGroupInContainerCount | Should -BeTrue }
        $script:detail | Should -Match 'Groups in OUs \(OU=\) \| 1'
        $script:detail | Should -Match 'Groups in Containers \(CN=\) \| 1'
        $script:detail | Should -Match 'Groups with Other Parent Types \| 1'
    }
}
