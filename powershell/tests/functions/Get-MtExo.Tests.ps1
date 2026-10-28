Describe 'Get-MtExo -Request AdminAuditLogConfig' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        if (-not (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
            function global:Get-ConnectionInformation { }
        }

        # Connect-ExchangeOnline and Connect-IPPSSession each import a temporary module that exports
        # Get-AdminAuditLogConfig. The Security & Compliance copy is imported last, so an unqualified
        # call resolves to it and reports audit log ingestion as disabled (#1802).
        New-Module -Name tmpEXO_mttest -ScriptBlock {
            function Get-AdminAuditLogConfig { [PSCustomObject]@{ Name = 'Admin Audit Log Settings'; UnifiedAuditLogIngestionEnabled = $true } }
        } | Import-Module -Global -Force
        New-Module -Name tmpEOP_mttest -ScriptBlock {
            function Get-AdminAuditLogConfig { [PSCustomObject]@{ Name = 'Admin Audit Log Settings'; UnifiedAuditLogIngestionEnabled = $false } }
        } | Import-Module -Global -Force
    }

    AfterAll {
        Remove-Module tmpEXO_mttest, tmpEOP_mttest -Force -ErrorAction SilentlyContinue
        Clear-MtExoCache
    }

    BeforeEach {
        Clear-MtExoCache
    }

    It 'Calls the Exchange Online session copy when Security & Compliance is also connected' {
        Mock -ModuleName Maester Get-ConnectionInformation {
            [PSCustomObject]@{ Name = 'ExchangeOnline_1'; IsEopSession = $false; State = 'Connected'; ModuleName = 'tmpEXO_mttest' }
            [PSCustomObject]@{ Name = 'ExchangeOnline_2'; IsEopSession = $true; State = 'Connected'; ModuleName = 'tmpEOP_mttest' }
        }

        (Get-MtExo -Request AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled | Should -BeTrue
    }

    It 'Falls back to the unqualified command when no Exchange Online session is connected' {
        Mock -ModuleName Maester Get-ConnectionInformation {
            [PSCustomObject]@{ Name = 'ExchangeOnline_2'; IsEopSession = $true; State = 'Connected'; ModuleName = 'tmpEOP_mttest' }
        }

        (Get-MtExo -Request AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled | Should -BeFalse
    }
}
