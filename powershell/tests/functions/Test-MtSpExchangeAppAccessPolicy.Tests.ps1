BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtSpExchangeAppAccessPolicy

    if (-not (Get-Command Get-ApplicationAccessPolicy -ErrorAction SilentlyContinue)) {
        function global:Get-ApplicationAccessPolicy { param() }
        $script:removeAapStub = $true
    }
}

AfterAll {
    if ($script:removeAapStub) {
        Remove-Item -Path Function:\Get-ApplicationAccessPolicy -ErrorAction SilentlyContinue
    }
}

Describe 'Test-MtSpExchangeAppAccessPolicy' {
    BeforeEach {
        $script:Result = $null
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result)
            $script:Result = $Result
        }
        Mock -ModuleName Maester Get-MtLinkServicePrincipal { 'Contoso Mail App' }
        Mock -ModuleName Maester Get-ApplicationAccessPolicy { @() }
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw "Unexpected Graph request: $RelativeUri" }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
            $RelativeUri -eq 'servicePrincipals' -and $Filter -eq "appId eq '00000003-0000-0000-c000-000000000000'"
        } {
            [pscustomobject]@{
                Id = 'graph-sp'
                DisplayName = 'Microsoft Graph'
                AppRoles = @(
                    [pscustomobject]@{ Id = 'mail-read-role'; Value = 'Mail.Read' }
                    [pscustomobject]@{ Id = 'user-read-all-role'; Value = 'User.Read.All' }
                )
            }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
            $RelativeUri -eq 'servicePrincipals' -and -not $Filter
        } {
            [pscustomobject]@{ Id = 'app-sp'; AppId = 'mail-app'; DisplayName = 'Contoso Mail App' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
            $RelativeUri -eq 'servicePrincipals/app-sp/appRoleAssignments'
        } {
            [pscustomobject]@{ AppRoleId = 'mail-read-role'; ResourceId = 'graph-sp' }
        }
    }

    It 'Fails when the app has only a DenyAccess policy' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [pscustomobject]@{ AppId = @('mail-app'); AccessRight = 'DenyAccess' }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeFalse
        $script:Result | Should -BeLike '*Contoso Mail App*'
    }

    It 'Passes when a RestrictAccess policy includes the app' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [pscustomobject]@{ AppId = @('mail-app'); AccessRight = 'RestrictAccess' }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeTrue
    }

    It 'Passes when the app has both deny and restrict policies' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [pscustomobject]@{ AppId = @('mail-app'); AccessRight = 'DenyAccess' }
            [pscustomobject]@{ AppId = @('mail-app'); AccessRight = 'RestrictAccess' }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeTrue
    }

    It 'Does not count a RestrictAccess policy for another app' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [pscustomobject]@{ AppId = @('mail-app'); AccessRight = 'DenyAccess' }
            [pscustomobject]@{ AppId = @('other-app'); AccessRight = 'RestrictAccess' }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeFalse
    }

    It 'Recognizes an app in a policy with several AppIds' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [pscustomobject]@{ AppId = @('other-app', 'mail-app'); AccessRight = 'RestrictAccess' }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeTrue
    }

    It 'Fails when no application access policies exist' {
        Test-MtSpExchangeAppAccessPolicy | Should -BeFalse
    }

    It 'Does not accept a policy with no access right as protection' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [pscustomobject]@{ AppId = @('mail-app') }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeFalse
    }

    It 'Propagates Exchange errors instead of reporting compliance' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy { throw 'Access denied' }

        { Test-MtSpExchangeAppAccessPolicy } | Should -Throw '*Access denied*'
    }

    It 'Handles the localized Exchange REST response when no policies exist' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            $exception = [System.Exception]::new('Der Vorgang konnte nicht ausgeführt werden, weil das Objekt nicht gefunden wurde.')
            $exception.Data['RemoteException'] = [pscustomobject]@{
                TypeName = 'Microsoft.Exchange.Configuration.Tasks.ManagementObjectNotFoundException'
            }
            throw $exception
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeFalse
        $script:Result | Should -BeLike '*Contoso Mail App*'
    }

    It 'Keeps compatibility with the English no-policies response' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy { throw "The object couldn't be found." }

        Test-MtSpExchangeAppAccessPolicy | Should -BeFalse
    }

    It 'Does not swallow other structured Exchange REST errors' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            $exception = [System.Exception]::new('Zugriff verweigert.')
            $exception.Data['RemoteException'] = [pscustomobject]@{ TypeName = 'SomeOtherServerException' }
            throw $exception
        }

        { Test-MtSpExchangeAppAccessPolicy } | Should -Throw '*Zugriff verweigert*'
    }

    It 'Propagates Graph errors instead of treating unreadable assignments as empty' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
            $RelativeUri -eq 'servicePrincipals/app-sp/appRoleAssignments'
        } { throw 'Graph unavailable' }

        { Test-MtSpExchangeAppAccessPolicy } | Should -Throw '*Graph unavailable*'
    }

    It 'Resolves an app role against the API the assignment points to' {
        # Microsoft Graph's Mail.Read role ID, but assigned on another API: it is not Mail.Read there.
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
            $RelativeUri -eq 'servicePrincipals/app-sp/appRoleAssignments'
        } {
            [pscustomobject]@{ AppRoleId = 'mail-read-role'; ResourceId = 'other-api-sp' }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeTrue
        $script:Result | Should -BeExactly 'Well done. No applications with Exchange permissions were found.'
    }

    It 'Lists an assignment whose role the API does not define instead of dropping it' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
            $RelativeUri -eq 'servicePrincipals/app-sp/appRoleAssignments'
        } {
            [pscustomobject]@{ AppRoleId = 'mail-read-role'; ResourceId = 'graph-sp' }
            [pscustomobject]@{ AppRoleId = 'unknown-role'; ResourceId = 'graph-sp' }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeFalse
        $script:Result | Should -Match ([regex]::Escape('| Contoso Mail App | mail-app | Mail.Read |'))
        $script:Result | Should -Match '### App Role Assignments Not Evaluated'
        $script:Result | Should -Match ([regex]::Escape('| Contoso Mail App | Microsoft Graph | unknown-role |'))
    }

    It 'Does not list the default access role as not evaluated' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter {
            $RelativeUri -eq 'servicePrincipals/app-sp/appRoleAssignments'
        } {
            [pscustomobject]@{ AppRoleId = '00000000-0000-0000-0000-000000000000'; ResourceId = 'graph-sp' }
        }

        Test-MtSpExchangeAppAccessPolicy | Should -BeTrue
        $script:Result | Should -Not -Match 'Not Evaluated'
    }
}

Describe 'MT.1058 native engine results' {
    BeforeEach {
        Mock -ModuleName Maester Get-MgContext { $null }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($RelativeUri -eq 'servicePrincipals' -and $Filter -eq "appId eq '00000003-0000-0000-c000-000000000000'") {
                [pscustomobject]@{ Id = 'graph-sp'; DisplayName = 'Microsoft Graph'; AppRoles = @([pscustomobject]@{ Id = 'mail-read-role'; Value = 'Mail.Read' }) }
            } elseif ($RelativeUri -eq 'servicePrincipals' -and $Filter) {
                @()
            } elseif ($RelativeUri -eq 'servicePrincipals') {
                [pscustomobject]@{ Id = 'app-sp'; AppId = 'mail-app'; DisplayName = 'Contoso Mail App' }
            } elseif ($RelativeUri -eq 'servicePrincipals/app-sp/appRoleAssignments') {
                [pscustomobject]@{ AppRoleId = 'mail-read-role'; ResourceId = 'graph-sp' }
            } else {
                throw "Unexpected Graph request: $RelativeUri"
            }
        }
        Mock -ModuleName Maester Get-MtLinkServicePrincipal { 'Contoso Mail App' }
        $script:config = [pscustomobject]@{
            Environment = [pscustomobject]@{
                Services = [pscustomobject]@{ Graph = $true; ExchangeOnline = $true }
                Licenses = @()
            }
        }
    }

    It 'Records <AccessRight> as <Expected> through Invoke-MtTest' -ForEach @(
        @{ AccessRight = 'DenyAccess'; Expected = 'Failed' }
        @{ AccessRight = 'RestrictAccess'; Expected = 'Passed' }
    ) {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [pscustomobject]@{ AppId = @('mail-app'); AccessRight = $AccessRight }
        }

        $rows = @(Invoke-MtTest -Id 'MT.1058' -Config $script:config)
        $rows | Should -HaveCount 1
        $rows[0].Result | Should -Be $Expected
        $rows[0].ResultDetail.TestResult | Should -Not -BeNullOrEmpty
    }
}
