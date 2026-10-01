BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Write-MtGraphConsentHelp' {
    BeforeEach {
        Mock Write-Host -ModuleName Maester {}
    }

    It 'Shows guidance for <Message>' -ForEach @(
        @{ Message = 'InteractiveBrowserCredential authentication failed: User canceled authentication.' }
        @{ Message = 'AADSTS65001: The user or administrator has not consented to use the application.' }
        @{ Message = 'AADSTS90094: The grant requires admin permission.' }
        @{ Message = 'AADSTS90095: Admin consent is required for the permissions requested by this application.' }
    ) {
        $result = InModuleScope Maester -Parameters @{ Message = $Message } {
            param($Message)
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new($Message), 'AuthFailed', 'AuthenticationError', $null)
            Write-MtGraphConsentHelp -ErrorRecord $errorRecord
        }

        $result | Should -BeTrue
        Should -Invoke Write-Host -ModuleName Maester -ParameterFilter { $Object -match 'Consent on behalf of your organization' }
    }

    It 'Does not show guidance for unrelated errors' {
        $result = InModuleScope Maester {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Certificate was not found in certificate store.'), 'AuthFailed', 'AuthenticationError', $null)
            Write-MtGraphConsentHelp -ErrorRecord $errorRecord
        }

        $result | Should -BeFalse
        Should -Invoke Write-Host -ModuleName Maester -Times 0 -Exactly
    }

    It 'Includes the Connect-Maester switches and client ID in the consent command' {
        InModuleScope Maester {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('User canceled authentication'), 'AuthFailed', 'AuthenticationError', $null)
            $null = Write-MtGraphConsentHelp -ErrorRecord $errorRecord -GraphClientId 'my-client-id' -SendMail -Privileged
        }

        Should -Invoke Write-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Object -match [regex]::Escape("Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail -Privileged) -ClientId 'my-client-id'")
        }
    }

    It 'Uses Get-MtGraphScope without switches by default' {
        InModuleScope Maester {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('User canceled authentication'), 'AuthFailed', 'AuthenticationError', $null)
            $null = Write-MtGraphConsentHelp -ErrorRecord $errorRecord
        }

        Should -Invoke Write-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Object -match [regex]::Escape('Connect-MgGraph -Scopes (Get-MtGraphScope)') -and $Object -notmatch 'ClientId'
        }
    }

    It 'Includes the tenant and cloud in both commands' {
        InModuleScope Maester {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('AADSTS65001: consent required'), 'AuthFailed', 'AuthenticationError', $null)
            $null = Write-MtGraphConsentHelp -ErrorRecord $errorRecord -TenantId 'contoso.onmicrosoft.com' -Environment USGov -SendMail
        }

        Should -Invoke Write-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Object -match [regex]::Escape("Connect-MgGraph -Scopes (Get-MtGraphScope -SendMail) -TenantId 'contoso.onmicrosoft.com' -Environment USGov")
        }
        Should -Invoke Write-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Object -match [regex]::Escape("Connect-Maester -GraphClientId '<application-client-id>' -TenantId 'contoso.onmicrosoft.com' -Environment USGov -SendMail")
        }
    }

    It 'Does not add -Environment for the Global cloud' {
        InModuleScope Maester {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('AADSTS65001: consent required'), 'AuthFailed', 'AuthenticationError', $null)
            $null = Write-MtGraphConsentHelp -ErrorRecord $errorRecord -Environment Global
        }

        Should -Invoke Write-Host -ModuleName Maester -Times 0 -Exactly -ParameterFilter { $Object -match '-Environment' }
    }

    It 'Makes the guidance conditional when the user only canceled sign-in' {
        InModuleScope Maester {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('User canceled authentication'), 'AuthFailed', 'AuthenticationError', $null)
            $null = Write-MtGraphConsentHelp -ErrorRecord $errorRecord
        }

        Should -Invoke Write-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Object -match 'If you closed the sign-in window' }
        Should -Invoke Write-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Object -match '^In that case, ask' }
    }

    It 'States the consent problem directly for AADSTS approval errors' {
        InModuleScope Maester {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('AADSTS90094: The grant requires admin permission.'), 'AuthFailed', 'AuthenticationError', $null)
            $null = Write-MtGraphConsentHelp -ErrorRecord $errorRecord
        }

        Should -Invoke Write-Host -ModuleName Maester -Times 0 -Exactly -ParameterFilter { $Object -match 'If you closed the sign-in window' }
        Should -Invoke Write-Host -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Object -match '^Ask a Global Administrator' }
    }
}
