BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue

    function New-TestFile {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([string] $Folder, [string] $Id, [string] $Service)
        $null = New-Item -ItemType Directory -Path $Folder -Force
        $name = 'Test-' + ($Id -replace '[^A-Za-z0-9]', '')
        @"
function $name {
    [MaesterTest(Id = '$Id', Title = 'Title of $Id', Severity = 'High', Service = '$Service')]
    [CmdletBinding()]
    param()
    Add-MtTestResultDetail -Result 'ok'
    `$true
}
"@ | Set-Content (Join-Path $Folder "Test.$Id.ps1")
        "Description of $Id.`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $Folder "Test.$Id.md")
        $Folder
    }

    function Invoke-GraphCheckRun {
        param([string] $Folder, [hashtable] $Extra = @{})
        $parameters = @{
            Path = $Folder; SkipBuiltIn = $true; NonInteractive = $true; DisableTelemetry = $true; SkipVersionCheck = $true
            OutputFolder = (Join-Path $TestDrive "$(Split-Path $Folder -Leaf)-out"); PassThru = $true
        }
        foreach ($key in $Extra.Keys) { $parameters[$key] = $Extra[$key] }
        Invoke-Maester @parameters 6>$null
    }
}

Describe 'Test-MtGraphRequired' {
    It 'Is <Expected> for a plan row with Service <Service> and disposition <Disposition> <ReasonCode>' -TestCases @(
        @{ Service = @('Graph'); Disposition = 'Run'; ReasonCode = $null; Expected = $true }
        @{ Service = @('Graph', 'Exchange'); Disposition = 'Run'; ReasonCode = $null; Expected = $true }
        @{ Service = @('Graph'); Disposition = 'Skipped'; ReasonCode = 'ServiceNotConnected'; Expected = $true }
        @{ Service = @('Graph'); Disposition = 'Skipped'; ReasonCode = 'PlatformMismatch'; Expected = $false }
        @{ Service = @('Graph'); Disposition = 'NotRun'; ReasonCode = 'Preview'; Expected = $false }
        @{ Service = @('ActiveDirectory'); Disposition = 'Run'; ReasonCode = $null; Expected = $false }
        @{ Service = @(); Disposition = 'Run'; ReasonCode = $null; Expected = $false }
    ) {
        $row = [pscustomobject]@{ Test = [pscustomobject]@{ Service = $Service }; Disposition = $Disposition; ReasonCode = $ReasonCode }
        InModuleScope Maester -Parameters @{ Row = $row } { Test-MtGraphRequired -Plan @($Row) } | Should -Be $Expected
    }

    It 'Is false for an empty plan and true when the run has Pester-format tests' {
        InModuleScope Maester { Test-MtGraphRequired -Plan @() } | Should -BeFalse
        InModuleScope Maester { Test-MtGraphRequired -Plan @() -PesterTest } | Should -BeTrue
    }
}

Describe 'Invoke-Maester checks the Graph connection only when the run needs it' {
    BeforeEach {
        Mock -ModuleName Maester Test-MtContext { throw 'Graph connection checked.' }
    }

    It 'Runs tests that do not use Graph without -SkipGraphConnect' {
        $folder = New-TestFile -Folder (Join-Path $TestDrive 'no-graph') -Id 'CONTOSO.1' -Service 'None'
        $result = Invoke-GraphCheckRun -Folder $folder
        $result.TotalCount | Should -Be 1
        $result.Tests[0].Result | Should -Be 'Passed'
        Should -Invoke -ModuleName Maester Test-MtContext -Times 0 -Exactly
    }

    It 'Checks the connection when a selected test uses Graph' {
        $folder = New-TestFile -Folder (Join-Path $TestDrive 'graph') -Id 'CONTOSO.2' -Service 'Graph'
        { Invoke-GraphCheckRun -Folder $folder } | Should -Throw 'Graph connection checked.'
        Should -Invoke -ModuleName Maester Test-MtContext -Times 1 -Exactly
    }

    It 'Does not check the connection when the Graph test is not selected' {
        $folder = Join-Path $TestDrive 'mixed'
        $null = New-TestFile -Folder $folder -Id 'CONTOSO.3' -Service 'Graph'
        $null = New-TestFile -Folder $folder -Id 'CONTOSO.4' -Service 'None'
        $result = Invoke-GraphCheckRun -Folder $folder -Extra @{ TestId = 'CONTOSO.4' }
        @($result.Tests | Where-Object Result -EQ 'Passed').Id | Should -Be 'CONTOSO.4'
        Should -Invoke -ModuleName Maester Test-MtContext -Times 0 -Exactly
    }

    It 'Checks the connection when the run has Pester-format tests' {
        $folder = Join-Path $TestDrive 'pester'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'Custom') -Force
        "Describe 'Contoso' { It 'works' { `$true | Should -BeTrue } }" | Set-Content (Join-Path $folder 'Custom/Contoso.Tests.ps1')
        { Invoke-GraphCheckRun -Folder $folder } | Should -Throw 'Graph connection checked.'
        Should -Invoke -ModuleName Maester Test-MtContext -Times 1 -Exactly
    }

    It 'Checks the connection with the mail scope when the results are sent by mail' {
        $folder = New-TestFile -Folder (Join-Path $TestDrive 'mail') -Id 'CONTOSO.5' -Service 'None'
        { Invoke-GraphCheckRun -Folder $folder -Extra @{ MailRecipient = 'admin@contoso.com' } } | Should -Throw 'Graph connection checked.'
        Should -Invoke -ModuleName Maester Test-MtContext -Times 1 -Exactly -ParameterFilter { $SendMail }
    }

    It 'Does not check the connection with -SkipGraphConnect' {
        $folder = New-TestFile -Folder (Join-Path $TestDrive 'skip') -Id 'CONTOSO.6' -Service 'Graph'
        $null = Invoke-GraphCheckRun -Folder $folder -Extra @{ SkipGraphConnect = $true; DryRun = $true }
        Should -Invoke -ModuleName Maester Test-MtContext -Times 0 -Exactly
    }
}
