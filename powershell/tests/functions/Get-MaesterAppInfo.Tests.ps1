BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Get-MaesterAppInfo
}

Describe 'Get-MaesterAppInfo' -Tag 'Unit' {
    BeforeAll {
        $script:app = [pscustomobject]@{ displayName = 'maester'; appId = 'app-1'; id = 'obj-1'; description = ''; createdDateTime = ''; tags = @('maester') }
    }

    AfterEach {
        InModuleScope Maester { $__MtSession.AdminPortalUrl = @{} }
    }

    It 'builds the portal link from the Entra portal address when the session holds the portal table' {
        InModuleScope Maester {
            $__MtSession.AdminPortalUrl = @{ Azure = 'https://portal.azure.com/'; Entra = 'https://entra.microsoft.com/'; Intune = 'https://intune.microsoft.com/' }
        }

        $info = Get-MaesterAppInfo -App $script:app

        $info.PortalLink | Should -Be 'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/app-1'
    }

    It 'uses the Entra address of a sovereign cloud' {
        InModuleScope Maester {
            $__MtSession.AdminPortalUrl = @{ Entra = 'https://entra.microsoft.us/' }
        }

        (Get-MaesterAppInfo -App $script:app).PortalLink | Should -BeLike 'https://entra.microsoft.us/#view/*'
    }

    It 'falls back to the public Entra address when the session has no portal addresses' {
        InModuleScope Maester { $__MtSession.AdminPortalUrl = @{} }

        (Get-MaesterAppInfo -App $script:app).PortalLink | Should -BeLike 'https://entra.microsoft.com/#view/*'
    }
}
