[CmdletBinding()]
param ()

$motd = @"

.___  ___.      ___       _______     _______.___________. _______ .______         ____    ____  ___      __
|   \/   |     /   \     |   ____|   /       |           ||   ____||   _  \        \   \  /   / / _ \    /_ |
|  \  /  |    /  ^  \    |  |__     |   (--------|  |----``|  |__   |  |_)  |        \   \/   / | | | |    | |
|  |\/|  |   /  /_\  \   |   __|     \   \       |  |     |   __|  |      /          \      /  | | | |    | |
|  |  |  |  /  _____  \  |  |____.----)   |      |  |     |  |____ |  |\  \----.      \    /   | |_| |  __| |
|__|  |__| /__/     \__\ |_______|_______/       |__|     |_______|| _| ``._____|       \__/     \___/  (__)_|


"@
Write-Host -ForegroundColor Green -Object $motd

$RequiredScopes = @(
    'Policy.Read.All'
    'Directory.Read.All'
    'Policy.ReadWrite.ConditionalAccess'
)
$CurrentScopes = Get-MgContext | Select-Object -ExpandProperty Scopes
try {
    $RequiredScopesOkay = [bool][string]::IsNullOrWhiteSpace( $( Compare-Object -ReferenceObject $CurrentScopes -DifferenceObject $RequiredScopes | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject ) )
} catch {
    $RequiredScopesOkay = $false
}

if ( -not $RequiredScopesOkay ) {
    Connect-MgGraph -UseDeviceAuthentication -Scope $RequiredScopes -NoWelcome
}

$PSDefaultParameterValues = @{
    'Invoke-MgGraphRequest:Verbose' = $false
}


$PesterConfiguration = New-PesterConfiguration -Hashtable @{
    Filter     = @{
        # Use the filter configuration to only specify the tests
        Tag = "All"
    }
    TestResult = @{
        Enabled = $true
    }
    Run        = @{
        Exit = $true
    }
    Should     = @{
        ErrorAction = 'Continue'
    }
    Output     = @{
        Verbosity = 'Detailed'
    }
}

Clear-MtGraphCache #Reset the cache to avoid stale data

Invoke-Pester -Configuration $PesterConfiguration
