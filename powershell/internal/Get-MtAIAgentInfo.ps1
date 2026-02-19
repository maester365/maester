<#
.SYNOPSIS
    Retrieves Copilot Studio agent information via the Dataverse API.

.DESCRIPTION
    Queries the Dataverse OData API to retrieve configuration and security details
    for Copilot Studio agents, including their topics and tools. Requires the
    DataverseEnvironmentUrl to be configured in maester-config.json GlobalSettings
    and an active Dataverse connection (Connect-Maester -Service Dataverse).

    Results are cached in the module session for reuse by multiple test functions.

.EXAMPLE
    Get-MtAIAgentInfo

    Returns a list of AI agent objects with their configuration properties.

.LINK
    https://maester.dev/docs/commands/Get-MtAIAgentInfo
#>

function Get-MtAIAgentInfo {
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param()

    if ($null -ne $__MtSession.AIAgentInfo) {
        if ($__MtSession.AIAgentInfo.Count -eq 0) {
            Write-Verbose "Previous Copilot Studio query failed or returned no results. Skipping."
            return $null
        }
        Write-Verbose "Returning cached AI agent info."
        return $__MtSession.AIAgentInfo
    }

    # Get the Dataverse environment URL from config (used to connect to Copilot Studio)
    $dataverseUrl = Get-MtMaesterConfigGlobalSetting -SettingName 'DataverseEnvironmentUrl'

    if ([string]::IsNullOrEmpty($dataverseUrl)) {
        Write-Warning "DataverseEnvironmentUrl not configured in maester-config.json GlobalSettings. Add 'DataverseEnvironmentUrl' with your Copilot Studio environment URL (e.g. 'org12345.crm.dynamics.com')."
        $__MtSession.AIAgentInfo = @()
        return $null
    }

    Write-Verbose "Querying Copilot Studio agents from Dataverse: $dataverseUrl"

    # Normalize URL - ensure https:// prefix and no trailing slash
    $dataverseUrl = $dataverseUrl.TrimEnd('/')
    if ($dataverseUrl -match '^https?://') {
        $resourceUrl = $dataverseUrl -replace '\.api\.', '.'
    } else {
        $resourceUrl = "https://$dataverseUrl"
    }

    # Derive API URL by inserting .api. after the hostname prefix
    # e.g. https://org5acae060.crm19.dynamics.com -> https://org5acae060.api.crm19.dynamics.com
    $apiUrl = $resourceUrl -replace '(https://[^.]+)\.', '$1.api.'
    $apiBase = "$apiUrl/api/data/v9.2"

    # Get access token via Az module
    try {
        $tokenResult = Get-AzAccessToken -ResourceUrl $resourceUrl -ErrorAction Stop
        if ($tokenResult.Token -is [System.Security.SecureString]) {
            $token = $tokenResult.Token | ConvertFrom-SecureString -AsPlainText
        } else {
            $token = $tokenResult.Token
        }
    } catch {
        Write-Warning "Failed to get Dataverse access token for Copilot Studio. Ensure you are connected via 'Connect-Maester -Service Dataverse'. Error: $_"
        $__MtSession.AIAgentInfo = @()
        return $null
    }

    $headers = @{
        Authorization      = "Bearer $token"
        Accept             = 'application/json'
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
    }

    # Option set mappings (Dataverse stores these as integers)
    $accessControlPolicyMap = @{
        0 = 'Any'
        1 = 'Agent readers'
        2 = 'Group membership'
        3 = 'Any multitenant'
    }

    $authenticationModeMap = @{
        0 = 'Unspecified'
        1 = 'None'
        2 = 'Integrated'
        3 = 'Custom Entra ID'
        4 = 'Generic OAuth2'
    }

    $authenticationTriggerMap = @{
        0 = 'As Needed'
        1 = 'Always'
    }

    # Query all bots (exclude managed/built-in bots like 'Copilot in Power Apps')
    try {
        $selectFields = 'botid,name,accesscontrolpolicy,authenticationmode,authenticationtrigger,authorizedsecuritygroupids,statecode,statuscode,modifiedon,publishedon,configuration,schemaname,_ownerid_value,_createdby_value'
        $botsResponse = Invoke-RestMethod -Uri "$apiBase/bots?`$filter=ismanaged eq false&`$select=$selectFields" -Headers $headers -ErrorAction Stop
    } catch {
        Write-Warning "Failed to query Copilot Studio agents from Dataverse: $_"
        $__MtSession.AIAgentInfo = @()
        return $null
    }

    if ($null -eq $botsResponse.value -or $botsResponse.value.Count -eq 0) {
        Write-Verbose "No Copilot Studio agents found in the Dataverse environment."
        $__MtSession.AIAgentInfo = @()
        return $null
    }

    # Build a cache of systemuser UPNs for owner/creator resolution
    $userCache = @{}
    $userIds = @()
    foreach ($bot in $botsResponse.value) {
        if ($bot._ownerid_value -and -not $userCache.ContainsKey($bot._ownerid_value)) {
            $userIds += $bot._ownerid_value
            $userCache[$bot._ownerid_value] = $null
        }
        if ($bot._createdby_value -and -not $userCache.ContainsKey($bot._createdby_value)) {
            $userIds += $bot._createdby_value
            $userCache[$bot._createdby_value] = $null
        }
    }

    foreach ($userId in $userIds) {
        try {
            $user = Invoke-RestMethod -Uri "$apiBase/systemusers($userId)?`$select=domainname" -Headers $headers -ErrorAction Stop
            $userCache[$userId] = $user.domainname
        } catch {
            Write-Verbose "Could not resolve systemuser $userId : $_"
            $userCache[$userId] = $userId
        }
    }

    # Use the Dataverse URL as the environment identifier for display
    $environmentId = $resourceUrl -replace 'https?://', ''

    # Process each bot
    $agents = @()
    foreach ($bot in $botsResponse.value) {
        # Map option set values to strings
        $acpValue = if ($null -ne $bot.accesscontrolpolicy -and $accessControlPolicyMap.ContainsKey([int]$bot.accesscontrolpolicy)) {
            $accessControlPolicyMap[[int]$bot.accesscontrolpolicy]
        } else { "Unknown ($($bot.accesscontrolpolicy))" }

        $authModeValue = if ($null -ne $bot.authenticationmode -and $authenticationModeMap.ContainsKey([int]$bot.authenticationmode)) {
            $authenticationModeMap[[int]$bot.authenticationmode]
        } else { "Unknown ($($bot.authenticationmode))" }

        $authTriggerValue = if ($null -ne $bot.authenticationtrigger -and $authenticationTriggerMap.ContainsKey([int]$bot.authenticationtrigger)) {
            $authenticationTriggerMap[[int]$bot.authenticationtrigger]
        } else { "Unknown ($($bot.authenticationtrigger))" }

        # Determine agent status from statecode and publishedon
        $agentStatus = if ($bot.statecode -eq 1) { 'Inactive' }
            elseif ($null -ne $bot.publishedon) { 'Published' }
            else { 'Provisioned' }

        # Parse configuration for generative orchestration
        $generativeEnabled = $false
        if (-not [string]::IsNullOrEmpty($bot.configuration)) {
            try {
                $config = $bot.configuration | ConvertFrom-Json -ErrorAction Stop
                if ($config.settings.GenerativeActionsEnabled -eq $true) {
                    $generativeEnabled = $true
                }
            } catch {
                Write-Verbose "Could not parse configuration for bot $($bot.name): $_"
            }
        }

        # Get bot components (topics and tools)
        # componenttype 9 = Topic/Dialog, componenttype 15 = GptComponentMetadata
        $topicsData = @()
        $toolsData = @()
        try {
            $components = Invoke-RestMethod -Uri "$apiBase/botcomponents?`$filter=_parentbotid_value eq '$($bot.botid)' and componenttype eq 9&`$select=name,componenttype,data,schemaname" -Headers $headers -ErrorAction Stop
            foreach ($comp in $components.value) {
                if ([string]::IsNullOrEmpty($comp.data)) { continue }

                if ($comp.data -match 'kind:\s*TaskDialog') {
                    # Tool/action component (connector-based)
                    $toolsData += [PSCustomObject]@{
                        Name       = $comp.name
                        SchemaName = $comp.schemaname
                        Data       = $comp.data
                    }
                } else {
                    # Regular topic
                    $topicsData += [PSCustomObject]@{
                        Name       = $comp.name
                        SchemaName = $comp.schemaname
                        Data       = $comp.data
                    }
                }
            }
        } catch {
            Write-Verbose "Could not get bot components for $($bot.name): $_"
        }

        # Convert to JSON strings for pattern matching (tests use string matching)
        $topicsJson = if ($topicsData.Count -gt 0) {
            $topicsData | ConvertTo-Json -Depth 5 -Compress
        } else { $null }

        $toolsJson = if ($toolsData.Count -gt 0) {
            $toolsData | ConvertTo-Json -Depth 5 -Compress
        } else { $null }

        # Resolve owner and creator UPNs
        $ownerUpn = if ($bot._ownerid_value -and $userCache.ContainsKey($bot._ownerid_value)) {
            $userCache[$bot._ownerid_value]
        } else { $null }

        $creatorUpn = if ($bot._createdby_value -and $userCache.ContainsKey($bot._createdby_value)) {
            $userCache[$bot._createdby_value]
        } else { $null }

        $agents += [PSCustomObject]@{
            AIAgentId                        = $bot.botid
            AIAgentName                      = $bot.name
            AgentStatus                      = $agentStatus
            EnvironmentId                    = $environmentId
            AccessControlPolicy              = $acpValue
            UserAuthenticationType           = $authModeValue
            AuthenticationTrigger            = $authTriggerValue
            AuthorizedSecurityGroupIds       = $bot.authorizedsecuritygroupids
            AgentTopicsDetails               = $topicsJson
            AgentToolsDetails                = $toolsJson
            RawAgentInfo                     = $bot.configuration
            IsGenerativeOrchestrationEnabled = $generativeEnabled
            CreatorAccountUpn                = $creatorUpn
            OwnerAccountUpns                 = $ownerUpn
            LastPublishedTime                = $bot.publishedon
            LastModifiedTime                 = $bot.modifiedon
            SchemaName                       = $bot.schemaname
        }
    }

    $__MtSession.AIAgentInfo = $agents
    return $agents
}
