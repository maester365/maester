[CmdletBinding()]
param ()

$motd = @"

.___  ___.      ___       _______     _______.___________. _______ .______         ____    ____  ___      __
|   \/   |     /   \     |   ____|   /       |           ||   ____||   _  \        \   \  /   / / _ \    /_ |
|  \  /  |    /  ^  \    |  |__     |   (----`---|  |----`|  |__   |  |_)  |        \   \/   / | | | |    | |
|  |\/|  |   /  /_\  \   |   __|     \   \       |  |     |   __|  |      /          \      /  | | | |    | |
|  |  |  |  /  _____  \  |  |____.----)   |      |  |     |  |____ |  |\  \----.      \    /   | |_| |  __| |
|__|  |__| /__/     \__\ |_______|_______/       |__|     |_______|| _| `._____|       \__/     \___/  (__)_|


"@
Write-Host -ForegroundColor Green -Object $motd

$RequiredScopes = @(
    'Policy.Read.All'
    'Directory.Read.All'
    'Policy.ReadWrite.ConditionalAccess'
)
$CurrentScopes = Get-MgContext | Select-Object -ExpandProperty Scopes
$RequiredScopesOkay = [bool][string]::IsNullOrWhiteSpace( $( Compare-Object -ReferenceObject $CurrentScopes -DifferenceObject $RequiredScopes | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject ) )

if ( -not $RequiredScopesOkay ) {
    Connect-MgGraph -UseDeviceAuthentication -Scope $RequiredScopes
}

$PSDefaultParameterValues = @{
    'Invoke-MgGraphRequest:Verbose' = $false
}

#region Define variables to match your environment

$BreakGlassUserIds = @("a5032592-a8c0-4b9c-9b62-0d137cfede11")

# Create a hash table with Azure AD users to test, you can change the number of users to test
$TestNumberOfUsers = 1
$TestAzureADUser = New-Object -TypeName 'System.Collections.ArrayList'
$AADUsers = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users?`$top=$($TestNumberOfUsers+10)" | Select-Object -ExpandProperty value | Select-Object id, userPrincipalName
# Filter out the break glass users and limit it to $TestNumberOfUsers
$AADUsers = $AADUsers | Where-Object { $_.id -notcontains $BreakGlassUserIds } | Select-Object -First $TestNumberOfUsers
foreach ($User in $AADUsers) {
    $TempHashTable = @{
        userId            = $User.id
        userPrincipalName = $User.userPrincipalName
    }
    $TestAzureADUser.Add($TempHashTable) | Out-Null
}
#endregion

$configRunContainer = @(
    # Add global variables to the container
    New-PesterContainer -Path "*.Tests.ps1" -Data @{
        AzureADUser       = $TestAzureADUser
        BreakGlassUserIds = $BreakGlassUserIds
    }
)

$PesterConfiguration = New-PesterConfiguration -Hashtable @{
    Filter     = @{
        # Use the filter configuration to only specify the tests
        Tag = "All"
    }
    TestResult = @{
        Enabled = $true
    }
    Run        = @{
        Exit      = $true
        Container = $configRunContainer
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
