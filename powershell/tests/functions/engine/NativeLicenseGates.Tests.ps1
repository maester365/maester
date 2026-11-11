BeforeDiscovery {
    # Built-in tests whose inline Get-MtLicenseInformation guard became License. Each one must be
    # skipped by the engine on an unlicensed tenant and must run on a tenant with any one of its tokens.
    # MT.1181 had no guard: Conditional Access for agents needs Agent 365, and its agent risk condition
    # needs Entra ID P2 during the preview (#2585).
    $p1 = @{ License = @('AAD_PREMIUM'); Legacy = 'NotLicensedEntraIDP1' }
    $p2 = @{ License = @('AAD_PREMIUM_P2'); Legacy = 'NotLicensedEntraIDP2' }
    $p2OrGovernance = @{ License = @('AAD_PREMIUM_P2', 'Entra_Identity_Governance'); Legacy = 'NotLicensedEntraIDP2' }
    $p2AndAgent365 = @{ License = @('AAD_PREMIUM_P2&AGENT_365'); Legacy = 'NotLicensedEntraIDP2' }
    $mdoP1 = @{ License = @('ATP_ENTERPRISE'); Legacy = 'NotLicensedMdoP1' }
    $exoDlp = @{ License = @('EXCHANGE_DLP'); Legacy = 'NotLicensedExoDlp' }
    $intune = @{ License = @('INTUNE_A'); Legacy = 'NotLicensedIntune' }
    $converted = [ordered]@{
        'CISA.MS.AAD.1.1'  = $p1; 'CISA.MS.AAD.3.1' = $p1; 'CISA.MS.AAD.3.2' = $p1; 'CISA.MS.AAD.3.3' = $p1; 'CISA.MS.AAD.3.4' = $p1
        'CISA.MS.AAD.3.5'  = $p1; 'CISA.MS.AAD.3.6' = $p1; 'CISA.MS.AAD.3.7' = $p1; 'CISA.MS.AAD.3.8' = $p1; 'CISA.MS.AAD.4.1' = $p1
        'CISA.MS.AAD.2.1'  = $p2; 'CISA.MS.AAD.2.2' = $p2; 'CISA.MS.AAD.2.3' = $p2
        'CISA.MS.AAD.7.4'  = $p2OrGovernance; 'CISA.MS.AAD.7.5' = $p2OrGovernance; 'CISA.MS.AAD.7.6' = $p2OrGovernance; 'CISA.MS.AAD.7.7' = $p2OrGovernance
        'CISA.MS.SECURITYSUITE.2.1' = $mdoP1; 'CISA.MS.SECURITYSUITE.2.4' = $mdoP1; 'CISA.MS.EXO.11.3' = $mdoP1; 'CISA.MS.EXO.15.1' = $mdoP1
        'CISA.MS.EXO.15.2' = $mdoP1; 'CISA.MS.EXO.15.3' = $mdoP1
        'CISA.MS.EXO.17.3' = @{ License = @('M365_ADVANCED_AUDITING'); Legacy = 'NotLicensedAdvAudit' }
        'CISA.MS.EXO.8.1'  = $exoDlp; 'CISA.MS.EXO.8.2' = $exoDlp; 'CISA.MS.EXO.8.4' = $exoDlp
        'CIS.M365.1.3.6'   = @{ License = @('LOCKBOX_ENTERPRISE'); Legacy = 'NotLicensedCustomerLockbox' }
        'CIS.M365.2.1.1'   = $mdoP1; 'CIS.M365.2.1.4' = $mdoP1; 'CIS.M365.2.1.5' = $mdoP1; 'CIS.M365.2.1.7' = $mdoP1
        'MT.1053'          = $intune; 'MT.1096' = $intune; 'MT.1102' = $intune; 'MT.1105' = $intune
        'MT.1106'          = $p2OrGovernance; 'MT.1107' = $p2OrGovernance; 'MT.1108' = $p2OrGovernance; 'MT.1109' = $p2OrGovernance; 'MT.1110' = $p2OrGovernance
        'MT.1175'          = $exoDlp
        'MT.1181'          = $p2AndAgent365
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

# One It per behaviour over every case, naming the tests that break it, rather than one Describe per test.
Describe 'Licence gates of converted tests' {
    BeforeAll {
        Mock -ModuleName Maester Test-MtConnection { $true }
        Mock -ModuleName Maester Get-MgContext { $null }
        Mock -ModuleName Maester Invoke-MtGraphRequest { @() }
        Mock -ModuleName Maester Get-MtExo { @() }
        # Answer as an unlicensed tenant would, so a guard left in the body would skip the test.
        Mock -ModuleName Maester Get-MtLicenseInformation { if ($Product -eq 'EntraID') { 'Free' } elseif ($Product -eq 'MdoV2') { 'EOP' } else { $null } }
        $script:cases = $Cases
    }

    It 'Declare the licence in License' {
        $byId = @{}
        Get-MtTest -Id $script:cases.Id | ForEach-Object { $byId[$_.Id] = $_ }
        $problems = foreach ($case in $script:cases) {
            $declared = @($byId[$case.Id].License)
            if (($declared -join ',') -ne ($case.License -join ',')) { "$($case.Id) declares '$($declared -join ',')', expected '$($case.License -join ',')'" }
        }
        @($problems) | Should -BeNullOrEmpty
    }

    It 'Are skipped with LicenseNotFound on an unlicensed tenant' {
        $problems = foreach ($case in $script:cases) {
            $row = Invoke-MtTest -Id $case.Id -Config (New-Config -Licenses 'UNRELATED_PLAN')
            if ($row.Result -ne 'Skipped' -or $row.ReasonCode -ne 'LicenseNotFound' -or $row.ResultDetail.TestSkipped -ne $case.Legacy) {
                "$($case.Id): Result '$($row.Result)', ReasonCode '$($row.ReasonCode)', TestSkipped '$($row.ResultDetail.TestSkipped)', expected Skipped, LicenseNotFound, '$($case.Legacy)'"
            }
        }
        @($problems) | Should -BeNullOrEmpty
    }

    It 'Run on a tenant licensed for any one of their licences' {
        $problems = foreach ($case in $script:cases) {
            foreach ($license in $case.License) {
                # An element such as 'A&B' needs all of its tokens.
                $row = Invoke-MtTest -Id $case.Id -Config (New-Config -Licenses ($license -split '&'))
                if ($row.ReasonCode -eq 'LicenseNotFound') { "$($case.Id) with $($license): skipped with LicenseNotFound" }
                elseif ("$($row.ResultDetail.TestSkipped)" -like 'NotLicensed*') { "$($case.Id) with $($license): checks its own licence ($($row.ResultDetail.TestSkipped))" }
            }
        }
        @($problems) | Should -BeNullOrEmpty
    }

    It 'Skip MT.1181 on a tenant with only one of Entra ID P2 and Agent 365' {
        foreach ($license in 'AAD_PREMIUM_P2', 'AGENT_365') {
            $row = Invoke-MtTest -Id 'MT.1181' -Config (New-Config -Licenses $license)
            $row.Result | Should -Be 'Skipped' -Because "the tenant has only $license"
            $row.ReasonCode | Should -Be 'LicenseNotFound' -Because "the tenant has only $license"
        }
    }

    It 'Run MT.1181 on a tenant with both Entra ID P2 and Agent 365' {
        # The mocks return no Conditional Access policy, so the body runs and finds no blocking policy.
        $row = Invoke-MtTest -Id 'MT.1181' -Config (New-Config -Licenses 'AAD_PREMIUM_P2', 'AGENT_365')
        $row.Result | Should -Be 'Failed'
    }

    It 'evaluates Security Suite alerts without a Defender for Office 365 licence' {
        $row = Invoke-MtTest -Id 'CISA.MS.SECURITYSUITE.4.1' -Config (New-Config -Licenses 'UNRELATED_PLAN')
        $row.Result | Should -Be 'Failed'

        $row = Invoke-MtTest -Id 'CISA.MS.SECURITYSUITE.4.2' -Config (New-Config -Licenses 'UNRELATED_PLAN')
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'TestSkipped'
        $row.ResultDetail.TestSkipped | Should -Be 'Custom'
    }
}

Describe 'Licence skip message' {
    BeforeDiscovery {
        # Neither, one or both of AAD_PREMIUM_P2 and AGENT_365, as MT.1181 declares them.
        $script:MessageCases = @(
            @{ Name = 'one licence, missing'; License = @('AAD_PREMIUM_P2'); Has = @('UNRELATED_PLAN')
                Detail = 'This test requires Microsoft Entra ID P2. The tenant does not have it.'; Legacy = 'NotLicensedEntraIDP2' }
            @{ Name = 'two licences together, neither held'; License = @('AAD_PREMIUM_P2&AGENT_365'); Has = @('UNRELATED_PLAN')
                Detail = 'This test requires Microsoft Entra ID P2 and Agent 365. The tenant has neither.'; Legacy = 'NotLicensedEntraIDP2' }
            @{ Name = 'two licences together, only the first held'; License = @('AAD_PREMIUM_P2&AGENT_365'); Has = @('AAD_PREMIUM_P2')
                Detail = 'This test requires Microsoft Entra ID P2 and Agent 365. The tenant does not have Agent 365.'; Legacy = 'Custom' }
            @{ Name = 'two licences together, only the second held'; License = @('AAD_PREMIUM_P2&AGENT_365'); Has = @('AGENT_365')
                Detail = 'This test requires Microsoft Entra ID P2 and Agent 365. The tenant does not have Microsoft Entra ID P2.'; Legacy = 'NotLicensedEntraIDP2' }
            @{ Name = 'two licences together, the missing one with a 2.x code'; License = @('AGENT_365&INTUNE_A'); Has = @('AGENT_365')
                Detail = 'This test requires Agent 365 and Microsoft Intune. The tenant does not have Microsoft Intune.'; Legacy = 'NotLicensedIntune' }
            @{ Name = 'two alternatives, neither held'; License = @('AAD_PREMIUM_P2', 'Entra_Identity_Governance'); Has = @('UNRELATED_PLAN')
                Detail = 'This test requires Microsoft Entra ID P2 or Entra Identity Governance. The tenant has neither.'; Legacy = 'NotLicensedEntraIDP2' }
            @{ Name = 'alternatives that join licences, partly held'; License = @('INTUNE_A', 'AAD_PREMIUM_P2&AGENT_365'); Has = @('AAD_PREMIUM_P2')
                Detail = 'This test requires one of: Microsoft Intune; or Microsoft Entra ID P2 and Agent 365. The tenant has Microsoft Entra ID P2 but not Agent 365.'; Legacy = 'Custom' }
            @{ Name = 'a plan the licence table does not have'; License = @('CONTOSO_PLAN'); Has = @('UNRELATED_PLAN')
                Detail = 'This test requires CONTOSO_PLAN. The tenant does not have it.'; Legacy = 'Custom' }
            @{ Name = 'a table licence with a plan it does not have'; License = @('AAD_PREMIUM_P2&CONTOSO_PLAN'); Has = @('AAD_PREMIUM_P2')
                Detail = 'This test requires Microsoft Entra ID P2 and CONTOSO_PLAN. The tenant does not have CONTOSO_PLAN.'; Legacy = 'Custom' }
        )
    }

    BeforeAll {
        Mock -ModuleName Maester Test-MtConnection { $true }
        Mock -ModuleName Maester Get-MgContext { $null }
    }

    It 'Names the licences and what is missing: <Name>' -ForEach $MessageCases {
        $result = InModuleScope Maester -Parameters @{ License = $License; Has = $Has } {
            param($License, $Has)
            $test = [pscustomobject]@{ Platform = @(); TenantType = @(); Cloud = @(); Service = @(); UnregisteredServices = @(); License = $License }
            $context = [pscustomobject]@{
                Platform = 'Linux'; TenantType = 'Workforce'; Cloud = 'Global'; Services = [pscustomobject]@{}
                Licenses = [pscustomobject]@{ State = 'Known'; ServicePlanNames = $Has; ServicePlanIds = @(); SkuIds = @() }
            }
            Test-MtApplicability -Test $test -TenantContext $context -Enforce @{ Service = $false; License = $true; TenantType = $false; Cloud = $false }
        }
        $result.ReasonCode | Should -Be 'LicenseNotFound'
        $result.ReasonDetail | Should -Be $Detail
        $result.LegacySkipCode | Should -Be $Legacy
    }

    It 'Runs a test that needs two licences when the tenant has both' {
        $met = InModuleScope Maester {
            Test-MtLicenseRequirement -Requirement 'AAD_PREMIUM_P2&AGENT_365' -Licenses ([pscustomobject]@{ ServicePlanIds = @('eec0eb4f-6444-4f95-aba0-50c24d67f998', 'd0ce5ebb-9db0-491f-b780-8973a1d815fe'); SkuIds = @(); ServicePlanNames = @() })
        }
        $met | Should -BeTrue
    }

    It 'Counts Microsoft 365 E7 as Agent 365' {
        $met = InModuleScope Maester {
            Test-MtLicenseRequirement -Requirement 'AGENT_365' -Licenses ([pscustomobject]@{ ServicePlanIds = @(); SkuIds = @('9a18296a-025f-4e37-9ffa-30bf8d1ce775'); ServicePlanNames = @() })
        }
        $met | Should -BeTrue
    }

    It 'Gives every licence token a friendly name, from Microsoft or the table' {
        $unnamed = InModuleScope Maester {
            $table = Get-MtLicenseTable
            $names = Get-MtServicePlanName
            @($table.Tokens.Keys | Where-Object { -not $table.Tokens[$_].DisplayName -and -not $names.ContainsKey($_) })
        }
        $unnamed | Should -BeNullOrEmpty -Because 'a token that is a service plan takes Microsoft''s name; a grouping token needs a DisplayName'
    }

    It 'Names a plan the licence table does not have by Microsoft''s friendly name' {
        $result = InModuleScope Maester {
            $test = [pscustomobject]@{ Platform = @(); TenantType = @(); Cloud = @(); Service = @(); UnregisteredServices = @(); License = @('MCOEV') }
            $context = [pscustomobject]@{
                Platform = 'Linux'; TenantType = 'Workforce'; Cloud = 'Global'; Services = [pscustomobject]@{}
                Licenses = [pscustomobject]@{ State = 'Known'; ServicePlanNames = @('UNRELATED_PLAN'); ServicePlanIds = @(); SkuIds = @() }
            }
            Test-MtApplicability -Test $test -TenantContext $context -Enforce @{ Service = $false; License = $true; TenantType = $false; Cloud = $false }
        }
        $expected = (Get-Content "$PSScriptRoot/../../../assets/MaesterServicePlanNames.json" -Raw | ConvertFrom-Json).plans.MCOEV
        $expected | Should -Not -BeNullOrEmpty
        $result.ReasonDetail | Should -Be "This test requires $expected. The tenant does not have it."
    }

    It 'Keeps the module''s plan names in step with the website''s copy of Microsoft''s reference' {
        # Both files are written by website/scripts/update-license-service-plans.mjs from the same page.
        $website = Get-Content "$PSScriptRoot/../../../../website/src/data/license-service-plans.json" -Raw | ConvertFrom-Json
        $module = (Get-Content "$PSScriptRoot/../../../assets/MaesterServicePlanNames.json" -Raw | ConvertFrom-Json).plans
        $stale = @(foreach ($plan in $website.plans) {
                if ($plan[1] -and $module.($plan[0]) -cne $plan[1]) { $plan[0] }
            })
        $stale | Should -BeNullOrEmpty -Because 'run node website/scripts/update-license-service-plans.mjs to write both files'
        @($module.PSObject.Properties).Count | Should -Be @($website.plans | Where-Object { $_[1] }).Count
    }

    It 'Writes the message and the 2.x code to the result row' {
        $folder = Join-Path $TestDrive 'licence'
        $null = New-Item -ItemType Directory -Path $folder -Force
        @'
function Test-ContosoLicence {
    [MaesterTest(Id = 'CONTOSO.LIC.1', Title = 'Needs two licences', Severity = 'High', License = 'AAD_PREMIUM_P2&AGENT_365')]
    [CmdletBinding()]
    param()
    $true
}
'@ | Set-Content (Join-Path $folder 'Test.CONTOSO.LIC.1.ps1')
        "Needs two licences.`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $folder 'Test.CONTOSO.LIC.1.md')
        $config = [pscustomobject]@{ Environment = [pscustomobject]@{ Licenses = @('AAD_PREMIUM_P2'); Services = [pscustomobject]@{ Graph = $true } } }
        $row = Invoke-MtTest -Path $folder -Config $config 6>$null 3>$null
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'LicenseNotFound'
        $row.ReasonDetail | Should -Be 'This test requires Microsoft Entra ID P2 and Agent 365. The tenant does not have Agent 365.'
        $row.ResultDetail.TestSkipped | Should -Be 'Custom'
    }
}
