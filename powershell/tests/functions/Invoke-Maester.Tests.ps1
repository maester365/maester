Describe 'Invoke-Maester' {
    It 'Not connected to graph should return error' {
        if (Get-MgContext) { Disconnect-Graph } # Ensure we are disconnected
        { Invoke-Maester } | Should -Throw 'Not connected to Microsoft Graph.*'
    }

    It 'Validates smoke test results' {
        if (Get-MgContext) { Disconnect-Graph } # Ensure we are disconnected

        $maesterParams = @{
            Path = [System.IO.Path]::GetFullPath((Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "smoketests"))
            OutputFolder = [System.IO.Path]::GetFullPath((Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "test-results"))
            PassThru = $true
            SkipGraphConnect = $true
            NonInteractive = $true
            OutputFolderFileName = "TestResults"
            ExcludeTag = "testtag"
            NoLogo = $true
        }
        $r = Invoke-Maester @maesterParams

        # Validate the test results structure
        $r | Should -Not -BeNullOrEmpty -Because 'there should be a result'
        $r.TotalCount | Should -BeExactly 12 -Because 'counting total'
        $r.FailedCount | Should -BeExactly 1 -Because 'counting failed'
        $r.PassedCount | Should -BeExactly 1 -Because 'counting passed'
        $r.SkippedCount | Should -BeExactly 2 -Because 'counting skipped'
        $r.NotRunCount | Should -BeExactly 1 -Because 'counting notrun'
    }

}

