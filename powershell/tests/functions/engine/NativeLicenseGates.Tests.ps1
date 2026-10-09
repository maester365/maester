BeforeDiscovery {
    # Built-in tests whose inline Get-MtLicenseInformation guard became License. Each one must be
    # skipped by the engine on an unlicensed tenant and must run on a tenant with any one of its tokens.
    $p1 = @{ License = @('AAD_PREMIUM'); Legacy = 'NotLicensedEntraIDP1' }
    $p2 = @{ License = @('AAD_PREMIUM_P2'); Legacy = 'NotLicensedEntraIDP2' }
    $p2OrGovernance = @{ License = @('AAD_PREMIUM_P2', 'Entra_Identity_Governance'); Legacy = 'NotLicensedEntraIDP2' }
    $mdoP1 = @{ License = @('ATP_ENTERPRISE'); Legacy = 'NotLicensedMdoP1' }
    $exoDlp = @{ License = @('EXCHANGE_DLP'); Legacy = 'NotLicensedExoDlp' }
    $intune = @{ License = @('INTUNE_A'); Legacy = 'NotLicensedIntune' }
    $converted = [ordered]@{
        'CISA.MS.AAD.1.1'  = $p1; 'CISA.MS.AAD.3.1' = $p1; 'CISA.MS.AAD.3.2' = $p1; 'CISA.MS.AAD.3.3' = $p1; 'CISA.MS.AAD.3.4' = $p1
        'CISA.MS.AAD.3.5'  = $p1; 'CISA.MS.AAD.3.6' = $p1; 'CISA.MS.AAD.3.7' = $p1; 'CISA.MS.AAD.3.8' = $p1; 'CISA.MS.AAD.4.1' = $p1
        'CISA.MS.AAD.2.1'  = $p2; 'CISA.MS.AAD.2.2' = $p2; 'CISA.MS.AAD.2.3' = $p2
        'CISA.MS.AAD.7.4'  = $p2OrGovernance; 'CISA.MS.AAD.7.5' = $p2OrGovernance; 'CISA.MS.AAD.7.6' = $p2OrGovernance; 'CISA.MS.AAD.7.7' = $p2OrGovernance
        'CISA.MS.EXO.11.1' = $mdoP1; 'CISA.MS.EXO.11.2' = $mdoP1; 'CISA.MS.EXO.11.3' = $mdoP1; 'CISA.MS.EXO.15.1' = $mdoP1
        'CISA.MS.EXO.15.2' = $mdoP1; 'CISA.MS.EXO.15.3' = $mdoP1; 'CISA.MS.EXO.16.1' = $mdoP1; 'CISA.MS.EXO.16.2' = $mdoP1
        'CISA.MS.EXO.17.3' = @{ License = @('M365_ADVANCED_AUDITING'); Legacy = 'NotLicensedAdvAudit' }
        'CISA.MS.EXO.8.1'  = $exoDlp; 'CISA.MS.EXO.8.2' = $exoDlp; 'CISA.MS.EXO.8.4' = $exoDlp
        'CIS.M365.1.3.6'   = @{ License = @('LOCKBOX_ENTERPRISE'); Legacy = 'NotLicensedCustomerLockbox' }
        'CIS.M365.2.1.1'   = $mdoP1; 'CIS.M365.2.1.4' = $mdoP1; 'CIS.M365.2.1.5' = $mdoP1; 'CIS.M365.2.1.7' = $mdoP1
        'MT.1053'          = $intune; 'MT.1096' = $intune; 'MT.1102' = $intune; 'MT.1105' = $intune
        'MT.1106'          = $p2OrGovernance; 'MT.1107' = $p2OrGovernance; 'MT.1108' = $p2OrGovernance; 'MT.1109' = $p2OrGovernance; 'MT.1110' = $p2OrGovernance
        'MT.1175'          = $exoDlp
        'MT.1187'          = $p1; 'MT.1188' = $p1; 'MT.1189' = $p1; 'MT.1190' = $p1; 'MT.1191' = $p1; 'MT.1192' = $p1; 'MT.1193' = $p1; 'MT.1194' = $p1; 'MT.1195' = $p1
    }
    $script:Cases = foreach ($id in $converted.Keys) { @{ Id = $id; License = $converted[$id].License; Legacy = $converted[$id].Legacy } }
}

BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force -WarningAction SilentlyContinue

    function New-Config {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([string[]] $Licenses)
        $services = [pscustomobject]@{ Graph = $true; ExchangeOnline = $true; SecurityCompliance = $true; Teams = $true }
        [pscustomobject]@{ Environment = [pscustomobject]@{ Licenses = $Licenses; Services = $services } }
    }
}

Describe 'Licence gate of converted test <Id>' -ForEach $Cases {
    BeforeEach {
        Mock -ModuleName Maester Test-MtConnection { $true }
        Mock -ModuleName Maester Get-MgContext { $null }
        Mock -ModuleName Maester Invoke-MtGraphRequest { @() }
        Mock -ModuleName Maester Get-MtExo { @() }
        # Answer as an unlicensed tenant would, so a guard left in the body would skip the test.
        Mock -ModuleName Maester Get-MtLicenseInformation { if ($Product -eq 'EntraID') { 'Free' } elseif ($Product -eq 'MdoV2') { 'EOP' } else { $null } }
    }

    It 'Declares the licence in License' {
        @((Get-MtTest -Id $Id).License) | Should -Be $License
    }

    It 'Is skipped with LicenseNotFound on an unlicensed tenant' {
        $row = Invoke-MtTest -Id $Id -Config (New-Config -Licenses 'UNRELATED_PLAN')
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'LicenseNotFound'
        $row.ResultDetail.TestSkipped | Should -Be $Legacy
    }

    It 'Runs on a tenant licensed for <_>' -ForEach $License {
        $row = Invoke-MtTest -Id $Id -Config (New-Config -Licenses $_)
        $row.ReasonCode | Should -Not -Be 'LicenseNotFound'
        "$($row.ResultDetail.TestSkipped)" | Should -Not -BeLike 'NotLicensed*' -Because 'the test must not check its own licence'
    }
}
