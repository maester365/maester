Describe 'Test-MtCisaExoAlert' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtCisaExoAlert
        Mock -ModuleName Maester Add-MtTestResultDetail {}
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'P2' }

        # Alert policies as a tenant returns them: each tenant has its own object IDs, and
        # NotificationEnabled says whether an email is sent, not whether the alert is on.
        function New-TestAlert {
            param([string]$Name, [bool]$Disabled = $false)
            $id = [guid]::NewGuid()
            return [pscustomobject]@{ Name = $Name; Disabled = $Disabled; NotificationEnabled = $false; ExchangeObjectId = $id; Guid = $id }
        }
        $script:alertNames = @(
            'Suspicious email sending patterns detected'
            'Suspicious connector activity'
            'Suspicious Email Forwarding Activity'
            'Messages have been delayed'
            'Tenant restricted from sending unprovisioned email'
            'Tenant restricted from sending email'
            'A potentially malicious URL click was detected'
        )
    }

    It 'passes when every required alert is enabled' {
        Mock -ModuleName Maester Get-MtExo { $script:alertNames | ForEach-Object { New-TestAlert -Name $_ } }
        Test-MtCisaExoAlert | Should -BeTrue
    }

    It 'fails when a required alert is disabled' {
        Mock -ModuleName Maester Get-MtExo {
            $script:alertNames | ForEach-Object { New-TestAlert -Name $_ -Disabled ($_ -eq 'Messages have been delayed') }
        }
        Test-MtCisaExoAlert | Should -BeFalse
    }

    It 'does not require the URL click alert without Defender for Office 365 Plan 2' {
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'P1' }
        Mock -ModuleName Maester Get-MtExo { $script:alertNames | Select-Object -SkipLast 1 | ForEach-Object { New-TestAlert -Name $_ } }
        Test-MtCisaExoAlert | Should -BeTrue
    }
}
