BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtModuleImported' {
    It 'Is true for an imported module and false for one that is not' {
        InModuleScope Maester {
            Test-MtModuleImported 'Maester' | Should -BeTrue
            Test-MtModuleImported 'NoSuchModule.ForMaesterTests' | Should -BeFalse
        }
    }

    It 'Sees a module that was imported inside another module' {
        # A wrapper module that imports a service module in its own scope, as a company module that connects
        # to Exchange Online before it calls Invoke-Maester does. The inner module is not in the global table.
        $folder = Join-Path $TestDrive 'MtInnerForMaesterTests'
        $null = New-Item -ItemType Directory -Path $folder -Force
        'function Get-MtInnerThing { 1 }' | Set-Content (Join-Path $folder 'MtInnerForMaesterTests.psm1')
        $null = New-Module -Name MtWrapperForMaesterTests -ArgumentList $folder -ScriptBlock {
            param($Folder)
            Import-Module (Join-Path $Folder 'MtInnerForMaesterTests.psm1')
            function Get-MtWrapperThing { Get-MtInnerThing }
        } | Import-Module -PassThru
        try {
            Get-Module -Name MtInnerForMaesterTests | Should -BeNullOrEmpty -Because 'the test needs a module that only -All finds'
            InModuleScope Maester { Test-MtModuleImported 'MtInnerForMaesterTests' } | Should -BeTrue
        } finally {
            Remove-Module -Name MtWrapperForMaesterTests, MtInnerForMaesterTests -Force -ErrorAction SilentlyContinue
        }
    }
}
