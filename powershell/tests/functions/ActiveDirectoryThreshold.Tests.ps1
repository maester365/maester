#Requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}
#Requires -Version 7.0

<#
.SYNOPSIS
    Validation tests for Active Directory threshold configurations.

.DESCRIPTION
    These tests validate the stale computer threshold logic from Test.AD-DCOMP-06
    against live lab domains with configurable day thresholds. They require the
    Azure lab environment variables to be set and are skipped when unavailable.

.NOTES
    Lab credentials are read from environment variables:
    - ROOT_READER_PASSWORD
    - CHILD_READER_PASSWORD
    - FOREST_READER_PASSWORD
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

BeforeDiscovery {
    $script:HasLabCredentials =
        $env:ROOT_READER_PASSWORD -and
        $env:CHILD_READER_PASSWORD -and
        $env:FOREST_READER_PASSWORD

    $script:LabDomains = @(
        @{ Role = 'RootForest'; Fqdn = 'MiSouleDC02.misoule02.local'; Domain = 'misoule02.local'; User = 'misoule02.local\maesterreader'; Password = $env:ROOT_READER_PASSWORD }
        @{ Role = 'ChildDomain'; Fqdn = 'MiSouleDC03.child.misoule02.local'; Domain = 'child.misoule02.local'; User = 'child.misoule02.local\maesterreader'; Password = $env:CHILD_READER_PASSWORD }
        @{ Role = 'SeparateForest'; Fqdn = 'MiSouleDC04.misoule03.local'; Domain = 'misoule03.local'; User = 'misoule03.local\maesterreader'; Password = $env:FOREST_READER_PASSWORD }
    )
}

Describe 'Active Directory Threshold Validation' -Tag 'LabOnly', 'ActiveDirectory' -Skip:(-not $script:HasLabCredentials) {

    BeforeAll {
        if (-not (Get-Module Maester -ErrorAction SilentlyContinue)) {
            Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -ErrorAction Stop
        }
    }

    Context 'Stale enabled computer thresholds across lab domains' {

        It 'Should return PASS for the default 180-day threshold in <_.Domain>' -ForEach $script:LabDomains {
            $securePassword = ConvertTo-SecureString $_.Password -AsPlainText -Force
            $cred = [PSCredential]::new($_.User, $securePassword)

            try { Disconnect-Maester -ErrorAction SilentlyContinue | Out-Null } catch { $null = $null }

            $connectResult = Connect-Maester -Service ActiveDirectory -ActiveDirectoryCredential $cred `
                -ActiveDirectoryServer $_.Fqdn -ActiveDirectoryDomain $_.Domain `
                -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode Ldaps

            $connectResult | Should -Not -BeNullOrEmpty
            $connectResult.Status | Should -Be 'Connected'

            # Invoke the test through its supported entrypoint and assert pass outcome
            $testResult = Test-MtAdComputerStaleEnabledCount -StaleThresholdDays 180
            $testResult | Should -Be $true -Because 'AD-DCOMP-06 should pass when no stale enabled computers exist'

            # Diagnostic precondition: verify stale count is 0
            $adState = Get-MtADDomainState -Categories @('Computers') -Refresh
            $enabledComputers = $adState.Computers | Where-Object { $_.Enabled -eq $true }
            $staleThreshold = (Get-Date).AddDays(-180)
            $staleEnabledComputers = $enabledComputers | Where-Object {
                $null -eq $_.lastLogonDate -or $_.lastLogonDate -lt $staleThreshold
            }
            $staleCount = ($staleEnabledComputers | Measure-Object).Count
            $staleCount | Should -Be 0 -Because 'a fresh lab should have 0 stale enabled computers at 180 days'
        }

        It 'Should detect stale computers with a 1-day threshold in <_.Domain>' -ForEach $script:LabDomains {
            $securePassword = ConvertTo-SecureString $_.Password -AsPlainText -Force
            $cred = [PSCredential]::new($_.User, $securePassword)

            try { Disconnect-Maester -ErrorAction SilentlyContinue | Out-Null } catch { $null = $null }

            Connect-Maester -Service ActiveDirectory -ActiveDirectoryCredential $cred `
                -ActiveDirectoryServer $_.Fqdn -ActiveDirectoryDomain $_.Domain `
                -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode Ldaps | Out-Null

            $adState = Get-MtADDomainState -Categories @('Computers') -Refresh
            $enabledComputers = $adState.Computers | Where-Object { $_.Enabled -eq $true }
            $staleThreshold = (Get-Date).AddDays(-1)
            $staleEnabledComputers = $enabledComputers | Where-Object {
                $null -eq $_.lastLogonDate -or $_.lastLogonDate -lt $staleThreshold
            }
            $staleCount = ($staleEnabledComputers | Measure-Object).Count

            # Invoke the test through its supported entrypoint and assert investigate outcome
            $testResult = Test-MtAdComputerStaleEnabledCount -StaleThresholdDays 1
            $testResult | Should -Be $null -Because 'AD-DCOMP-06 should investigate when stale enabled computers exist'

            # With a 1-day threshold in a fresh lab, most or all computers appear stale
            $staleCount | Should -BeGreaterThan 0 -Because 'a 1-day threshold in a fresh lab should flag at least one computer as stale'
        }
    }
}
