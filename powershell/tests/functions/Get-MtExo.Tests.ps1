Describe 'Get-MtExo' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        if (-not (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
            function global:Get-ConnectionInformation { }
        }

        New-Module -Name tmpEXO_restricted_mttest -ScriptBlock {
            function Get-OrganizationConfig { }
        } | Import-Module -Global -Force
        # Connect-ExchangeOnline and Connect-IPPSSession each import a temporary module that exports
        # Get-AdminAuditLogConfig. The Security & Compliance copy is imported last, so an unqualified
        # call resolves to it and reports audit log ingestion as disabled (#1802).
        New-Module -Name tmpEXO_mttest -ScriptBlock {
            function Get-AdminAuditLogConfig { [PSCustomObject]@{ Name = 'Admin Audit Log Settings'; UnifiedAuditLogIngestionEnabled = $true } }
        } | Import-Module -Global -Force
        New-Module -Name tmpEOP_mttest -ScriptBlock {
            function Get-AdminAuditLogConfig { [PSCustomObject]@{ Name = 'Admin Audit Log Settings'; UnifiedAuditLogIngestionEnabled = $false } }
        } | Import-Module -Global -Force
        New-Module -Name tmpEXO_vip_mttest -ScriptBlock {
            function Get-User {
                [CmdletBinding()]
                param([switch]$IsVIP, [string]$ResultSize)
                [PSCustomObject]@{ UserPrincipalName = 'vip@example.test'; IsVIP = $IsVIP.IsPresent; ResultSize = $ResultSize }
            }
        } | Import-Module -Global -Force
    }

    AfterAll {
        Remove-Module tmpEXO_restricted_mttest, tmpEXO_mttest, tmpEOP_mttest, tmpEXO_vip_mttest -Force -ErrorAction SilentlyContinue
        Clear-MtExoCache
    }

    BeforeEach {
        Clear-MtExoCache
    }

    It 'Skips an earlier Exchange Online module that does not export the command' {
        Mock -ModuleName Maester Get-ConnectionInformation {
            [PSCustomObject]@{ Name = 'ExchangeOnline_1'; IsEopSession = $false; State = 'Connected'; ModuleName = (Join-Path ([IO.Path]::GetTempPath()) 'tmpEXO_restricted_mttest') }
            [PSCustomObject]@{ Name = 'ExchangeOnline_2'; IsEopSession = $false; State = 'Connected'; ModuleName = (Join-Path ([IO.Path]::GetTempPath()) 'tmpEXO_mttest') }
            [PSCustomObject]@{ Name = 'ExchangeOnline_3'; IsEopSession = $true; State = 'Connected'; ModuleName = (Join-Path ([IO.Path]::GetTempPath()) 'tmpEOP_mttest') }
        }

        (Get-MtExo -Request AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled | Should -BeTrue
    }

    It 'Falls back to the unqualified command when no Exchange Online session is connected' {
        Mock -ModuleName Maester Get-ConnectionInformation {
            [PSCustomObject]@{ Name = 'ExchangeOnline_2'; IsEopSession = $true; State = 'Connected'; ModuleName = 'tmpEOP_mttest' }
        }

        (Get-MtExo -Request AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled | Should -BeFalse
    }

    It 'Resolves a path-valued Exchange Online module name for VIP users' {
        Mock -ModuleName Maester Get-ConnectionInformation {
            [PSCustomObject]@{
                IsEopSession = $false
                State = 'Connected'
                ModuleName = Join-Path ([IO.Path]::GetTempPath()) 'tmpEXO_vip_mttest'
            }
        }

        $vipUsers = @(Get-MtExo -Request VipUser)
        $vipUsers.Count | Should -Be 1
        $vipUsers[0].UserPrincipalName | Should -Be 'vip@example.test'
        $vipUsers[0].IsVIP | Should -BeTrue
        $vipUsers[0].ResultSize | Should -Be 'Unlimited'
    }
}
