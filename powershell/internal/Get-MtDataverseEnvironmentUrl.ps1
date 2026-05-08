<#
.SYNOPSIS
    Auto-discovers a Dataverse environment URL using the Global Discovery Service.

.DESCRIPTION
    Calls the Dataverse Global Discovery Service (GDS) to find environments
    accessible by the current user. Returns the ApiUrl of the first enabled
    environment, or $null if none are found.

    The GDS endpoint is selected based on the current Azure environment
    (AzureCloud, AzureUSGovernment, AzureChinaCloud).

    This function is called by Connect-Maester as a fallback when
    DataverseEnvironmentUrl is not explicitly configured in maester-config.json.

.EXAMPLE
    Get-MtDataverseEnvironmentUrl

    Returns a URL like 'https://org12345.api.crm.dynamics.com' or $null.

.LINK
    https://learn.microsoft.com/en-us/power-apps/developer/data-platform/discovery-service
#>

function Get-MtDataverseEnvironmentUrl {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Determine the Azure environment from the current Az context
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext) {
        Write-Warning "No active Azure context. Ensure you are connected via 'Connect-Maester -Service Dataverse'."
        return $null
    }

    # Map Azure environment to Global Discovery Service URL
    # Commercial: covers standard commercial tenants
    # AzureUSGovernment: covers GCC High and USG (GCC uses AzureCloud and can configure DataverseEnvironmentUrl manually)
    # AzureChinaCloud: covers 21Vianet China
    $gdsUrlMap = @{
        'AzureCloud'        = 'https://globaldisco.crm.dynamics.com'
        'AzureUSGovernment' = 'https://globaldisco.crm.microsoftdynamics.us'
        'AzureChinaCloud'   = 'https://globaldisco.crm.dynamics.cn'
    }

    $azEnvName = $azContext.Environment.Name
    $gdsBaseUrl = $gdsUrlMap[$azEnvName]
    if (-not $gdsBaseUrl) {
        Write-Verbose "Unknown Azure environment '$azEnvName', defaulting to commercial Global Discovery Service."
        $gdsBaseUrl = $gdsUrlMap['AzureCloud']
    }

    Write-Verbose "Using Global Discovery Service: $gdsBaseUrl (Azure environment: $azEnvName)"

    # Get access token for the Global Discovery Service
    try {
        $gdsTokenResult = Get-AzAccessToken -ResourceUrl $gdsBaseUrl -ErrorAction Stop
        if ($gdsTokenResult.Token -is [System.Security.SecureString]) {
            $gdsToken = $gdsTokenResult.Token | ConvertFrom-SecureString -AsPlainText
        } else {
            $gdsToken = $gdsTokenResult.Token
        }
    } catch {
        Write-Warning "Failed to get Global Discovery Service token. Ensure you are connected via 'Connect-Maester -Service Dataverse'. Error: $_"
        return $null
    }

    $gdsHeaders = @{
        Authorization = "Bearer $gdsToken"
        Accept        = 'application/json'
    }

    # Query enabled Dataverse environments accessible by the current user
    try {
        $gdsResponse = Invoke-RestMethod -Uri "$gdsBaseUrl/api/discovery/v2.0/Instances?`$select=ApiUrl,FriendlyName,State&`$filter=State eq 0" -Headers $gdsHeaders -ErrorAction Stop
    } catch {
        Write-Warning "Failed to query Global Discovery Service for Dataverse environments: $_"
        return $null
    }

    if (-not $gdsResponse.value -or $gdsResponse.value.Count -eq 0) {
        Write-Warning "No Dataverse environments found via Global Discovery Service. If you have a GCC environment or a specific environment URL, configure 'DataverseEnvironmentUrl' in maester-config.json GlobalSettings."
        return $null
    }

    $selectedEnv = $gdsResponse.value[0]
    $discoveredUrl = $selectedEnv.ApiUrl

    if ($gdsResponse.value.Count -gt 1) {
        Write-Verbose "Found $($gdsResponse.value.Count) Dataverse environments. Using the first: '$($selectedEnv.FriendlyName)' ($discoveredUrl). To use a different environment, configure 'DataverseEnvironmentUrl' in maester-config.json GlobalSettings."
    } else {
        Write-Verbose "Auto-discovered Dataverse environment: '$($selectedEnv.FriendlyName)' ($discoveredUrl)"
    }

    return $discoveredUrl
}
