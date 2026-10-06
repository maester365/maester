# Service registry (Maester 3.0 design, section 6). [MaesterTest(Service = ...)] values are validated
# against these names. Every service a test lists must be connected for the test to run.
#
#   Probe           Test-MtConnection -Service value used to detect the connection
#   OptIn           tests are NotRun (OptInServiceNotConnected) instead of Skipped when not connected
#   RunspaceBound   the session exists only in the runspace that connected; such tests stay on the main lane
#   LegacySkipCode  the Add-MtTestResultDetail -SkippedBecause code written to ResultDetail, as 2.x guards did
#   Aliases         other names accepted in the attribute
@{
    SchemaVersion = '1.0'
    Services      = @{
        Graph              = @{ Probe = 'Graph'; OptIn = $false; RunspaceBound = $false; LegacySkipCode = 'NotConnectedGraph' }
        Azure              = @{ Probe = 'Azure'; OptIn = $false; RunspaceBound = $false; LegacySkipCode = 'NotConnectedAzure' }
        ExchangeOnline     = @{ Probe = 'ExchangeOnline'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedExchange'; Aliases = @('Exchange') }
        SecurityCompliance = @{ Probe = 'SecurityCompliance'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedSecurityCompliance'; Aliases = @('EOP') }
        SharePointOnline   = @{ Probe = 'SharePointOnline'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedSharePoint'; Aliases = @('SharePoint') }
        Teams              = @{ Probe = 'Teams'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedTeams' }
        # Dataverse uses the Graph sign-in to obtain its token.
        Dataverse          = @{ Probe = 'Graph'; OptIn = $false; RunspaceBound = $false; LegacySkipCode = 'NotConnectedGraph' }
        AzureDevOps        = @{ Probe = 'AzureDevOps'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedAzureDevOps' }
        GitHub             = @{ Probe = 'GitHub'; OptIn = $false; RunspaceBound = $false; LegacySkipCode = 'NotConnectedGitHub' }
        ActiveDirectory    = @{ Probe = 'ActiveDirectory'; OptIn = $true; RunspaceBound = $true; LegacySkipCode = 'NotConnectedActiveDirectory'; Aliases = @('AD') }
    }
}
