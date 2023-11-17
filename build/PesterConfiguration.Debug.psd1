@{
    Run          = @{
        PassThru = $true
    }
    Filter = @{
        #Tag        = 'Common'
        ExcludeTag = 'IntegrationTest'
    }
    Debug = @{
        ShowFullErrors = $false
        ShowNavigationMarkers = $false
        WriteDebugMessages = $false
    }
    Output       = @{
        Verbosity = 'Detailed'
    }
}