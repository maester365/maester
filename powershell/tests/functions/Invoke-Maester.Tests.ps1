Describe 'Invoke-Maester' {
    It 'Not connected to graph should return error' {
        if (Get-MgContext) { Disconnect-Graph } # Ensure we are disconnected
        { Invoke-Maester } | Should -Throw 'Not connected to Microsoft Graph.*'
    }
}

