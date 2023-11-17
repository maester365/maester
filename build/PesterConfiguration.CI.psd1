@{
    Run          = @{
        PassThru = $true
    }
    Filter       = @{
        #Tag        = ''
        ExcludeTag = 'Deferrable', 'IntegrationTest', 'Slow'
    }
    CodeCoverage = @{
        Enabled      = $true
        OutputFormat = 'JaCoCo'
        OutputPath   = '.\build\TestResults\CodeCoverage.xml'
        RecursePaths = $false
    }
    TestResult   = @{
        Enabled      = $true
        OutputFormat = 'NUnitXML'
        OutputPath   = '.\build\TestResults\TestResult.xml'
    }
    Output       = @{
        #Verbosity = 'Detailed'
    }
}