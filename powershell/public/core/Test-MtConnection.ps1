function Test-MtConnection {
    <#
    .SYNOPSIS
    Checks if the current session is connected to the specified service. Use -Verbose to see the connection status for each service.

    .DESCRIPTION
    Tests the connection for each service and returns $true if the session is connected to the specified service.

    .PARAMETER Service
    The service to check the connection for. Valid values are 'All', 'Azure', 'ExchangeOnline', 'Graph', 'SecurityCompliance' (or 'EOP'), and 'Teams'. Default is 'All'.

    .PARAMETER Details
    Return the full details of all connections instead of just a boolean value.

    .EXAMPLE
    Test-MtConnection -Service All

    Checks if the current session is connected to all services including Azure, Microsoft Graph, Exchange Online, Exchange Online Protection (SecurityCompliance), and Microsoft Teams. Returns a Boolean value.

    .EXAMPLE
    Test-MtConnection -Details

    Checks if the current session is connected to all services including Azure, Microsoft Graph, Exchange Online, Exchange Online Protection (SecurityCompliance), and Microsoft Teams. Returns a custom object that contains the connection details for all services.

    .EXAMPLE
    Test-MtConnection -Service Azure

    Checks if the current session is connected to Azure and returns a Boolean result.

    .LINK
    https://maester.dev/docs/commands/Test-MtConnection
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', 'AvoidUsingWriteHost', Justification = 'Sending colorful output to host in addition to rich object output.')]
    param(
        # Checks if the current session is connected to the specified service
        [ValidateSet('All', 'Azure', 'ExchangeOnline', 'EOP', 'Graph', 'SecurityCompliance', 'Teams')]
        [Parameter(Position = 0)]
        [string[]]$Service = 'Graph',

        # Return the full details of the connections
        [Parameter()]
        [switch]$Details
    )

    begin {
        $MtConnections = [PSCustomObject]@{
            PSTypeName  = 'Maester.Connections'
            Azure = $null
            Graph = $null
            ExchangeOnline = $null
            ExchangeOnlineProtection = $null
            Teams = $null
            AllConnected = $false
        }

        # This can potentially be replaced by $MtConnections.AllConnected but all functions that reference this function would need to be updated.
        $ConnectionState = $true
    }

    process {
        #region Azure
        if ($Service -contains 'Azure' -or $Service -contains 'All') {
            $IsConnected = $false
            try {
                $MtConnections.Azure = Get-AzContext
                $IsConnected = $null -ne ($MtConnections.Azure)
                # Validate that the credentials are still valid
                if ($IsConnected) {
                    $azError = @()
                    Invoke-AzRestMethod -Method GET -Path 'subscriptions?api-version=2022-12-01' -ErrorAction SilentlyContinue -ErrorVariable azError | Out-Null
                    if ($azError.Count -gt 0) {
                        $IsConnected = $false
                        $MtConnections.Azure = $null
                    }
                }
            } catch {
                $IsConnected = $false
                Write-Debug "Azure: $false"
            }
            Write-Verbose "Azure: $IsConnected"
            if (!$IsConnected) { $ConnectionState = $false }
        }
        #endregion Azure

        #region Graph
        if ($Service -contains 'Graph' -or $Service -contains 'All') {
            $IsConnected = $false
            try {
                $MtConnections.Graph = Get-MgContext
                $IsConnected = $null -ne ($MtConnections.Graph)
            } catch {
                # Re-test
                Write-Debug "Graph: $false"
            }
            Write-Verbose "Graph: $IsConnected"
            if (!$IsConnected) { $ConnectionState = $false }
        }
        # To Do: Add checks for required scopes.
        #endregion Graph

        #region Exchange Online
        if ($Service -contains 'ExchangeOnline' -or $Service -contains 'All') {
            $IsConnected = $false
            try {
                # Cache the connection information to avoid multiple calls to Get-ConnectionInformation. See https://github.com/maester365/maester/pull/1207
                $MtConnections.ExchangeOnline = (Get-MtExo -Request ConnectionInformation | Where-Object { $_.Name -match 'ExchangeOnline' -and $_.state -eq 'Connected' -and -not $_.IsEopSession })
                $IsConnected = $null -ne ($MtConnections.ExchangeOnline)
            } catch {
                Write-Debug "Exchange Online: $false"
            }
            Write-Verbose "Exchange Online: $IsConnected"
            if (!$IsConnected) { $ConnectionState = $false }
        }
        #endregion Exchange Online

        #region Exchange Online Protection (EOP)
        if (($Service -contains 'SecurityCompliance' -or $Service -contains 'EOP') -or $Service -contains 'All') {
            $IsConnected = $false
            try {
                # Cache the connection information to avoid multiple calls to Get-ConnectionInformation. See https://github.com/maester365/maester/pull/1207
                $MtConnections.ExchangeOnlineProtection = (Get-MtExo -Request ConnectionInformation | Where-Object { $_.Name -match 'ExchangeOnline' -and $_.state -eq 'Connected' -and $_.IsEopSession })
                $IsConnected = $null -ne ($MtConnections.ExchangeOnlineProtection)
            } catch {
                # Re-test
                Write-Debug "Security & Compliance: $false"
            }
            Write-Verbose "Security & Compliance: $IsConnected"
            if (!$IsConnected) { $ConnectionState = $false }
        }
        #endregion Exchange Online Protection (EOP)

        #region Teams
        if ($Service -contains 'Teams' -or $Service -contains 'All') {
            $IsConnected = $false
            try {
                $MtConnections.Teams = Get-CsTenant
                $IsConnected = $null -ne ($MtConnections.Teams)
            } catch {
                # Re-test
                Write-Debug "Teams: $false"
            }
            Write-Verbose "Teams: $IsConnected"
            if (!$IsConnected) { $ConnectionState = $false }
        }
        #endregion Teams

        if ($IsConnected) {
            $MtConnections.AllConnected = $true
        }

    }

    end {
        if ($Details.IsPresent) {
            # Return the full details of all active connections.
            $MtConnections
        } else {
            # Only return a boolean value indicating if all sessions are connected.
            $ConnectionState
        }
    }
}
