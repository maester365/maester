Describe 'Invoke-Maester' {
    It 'Not connected to graph should return error' {
        if (Get-MgContext) { Disconnect-Graph } # Ensure we are disconnected
        { Invoke-Maester } | Should -Throw 'Not connected to Microsoft Graph.*'
    }

    It 'Validates smoke test results' {
        if (Get-MgContext) { Disconnect-Graph } # Ensure we are disconnected

        $maesterParams = @{
            Path                 = [System.IO.Path]::GetFullPath((Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "smoketests"))
            OutputFolder         = [System.IO.Path]::GetFullPath((Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "test-results"))
            PassThru             = $true
            SkipGraphConnect     = $true
            NonInteractive       = $true
            OutputFolderFileName = "TestResults"
            ExcludeTag           = "testtag"
            NoLogo               = $true
        }
        $Result = Invoke-Maester @maesterParams
        # Dynamically calculate expected counts from smoke test files
        $smokeTestFiles = Get-ChildItem -Path $maesterParams.Path -Filter *.ps1
        $expectedTotalCount = 0
        $expectedPassedCount = 0
        $expectedFailedCount = 0
        $expectedSkippedCount = 0
        $expectedErrorCount = 0
        $expectedNotRunCount = 0
        foreach ($file in $smokeTestFiles) {
            $content = Get-Content -Path $file.FullName
            foreach ($line in $content) {
                if ($line -match 'It.*Smoke_Success') {
                    $expectedPassedCount++; $expectedTotalCount++
                } elseif ($line -match 'It.*Smoke_Failed') {
                    $expectedFailedCount++; $expectedTotalCount++
                } elseif ($line -match 'It.*Smoke_Error') {
                    $expectedErrorCount++; $expectedTotalCount++
                } elseif ($line -match 'It.*Smoke_Skipped') {
                    $expectedSkippedCount++; $expectedTotalCount++
                } elseif ($line -match 'It.*Smoke_NotRun') {
                    $expectedNotRunCount++; $expectedTotalCount++
                }
            }
        }

        # Validate the test results structure
        $Result | Should -Not -BeNullOrEmpty -Because 'there should be a result'
        $Result.TotalCount | Should -BeExactly $expectedTotalCount -Because 'counting Total'
        $Result.FailedCount | Should -BeExactly $expectedFailedCount -Because 'counting Failed'
        $Result.ErrorCount | Should -BeExactly $expectedErrorCount -Because 'counting Error'
        $Result.PassedCount | Should -BeExactly $expectedPassedCount -Because 'counting Success'
        $Result.SkippedCount | Should -BeExactly $expectedSkippedCount -Because 'counting Skipped'
        $Result.NotRunCount | Should -BeExactly $expectedNotRunCount -Because 'counting Notrun'
    }
}
