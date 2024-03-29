Describe 'Invoke-MtMaester' {
    It 'Not connected to graph should return error' {

        if (Get-MgContext) { Disconnect-Graph } # Ensure we are disconnected

        { Invoke-MtMaester } | Should -Throw "Not connected to Microsoft Graph.*"
    }
}

