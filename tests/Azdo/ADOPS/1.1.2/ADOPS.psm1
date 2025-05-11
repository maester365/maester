#region PreCode _PreModule_Requires

#Requires -Modules @{ ModuleName="AzAuth"; ModuleVersion="2.2.2" }

$script:AzTokenCache = 'adops.cache'

$script:loginMethod = 'Default'
#endregion PreCode _PreModule_Requires

#region GitAccessLevels

[Flags()] enum AccessLevels {
    Administer = 1
    GenericRead = 2
    GenericContribute = 4
    ForcePush = 8
    CreateBranch = 16
    CreateTag = 32
    ManageNote = 64
    PolicyExempt = 128
    CreateRepository = 256
    DeleteRepository = 512
    RenameRepository = 1024
    EditPolicies = 2048
    RemoveOthersLocks = 4096
    ManagePermissions = 8192
    PullRequestContribute = 16384
    PullRequestBypassPolicy = 32768
}
#endregion GitAccessLevels

#region ResourceType

enum ResourceType {
    VariableGroup
    Queue
    SecureFile
    Environment
}
#endregion ResourceType

#region SkipTest

class SkipTest : Attribute {
    [string[]]$TestNames

    SkipTest([string[]]$Name) {
        $this.TestNames = $Name
    }
}
#endregion SkipTest

#region ConvertRetentionSettingsGetToPatch

<#
.SYNOPSIS
Convert to responses from GET _apis/build/retention & PATCH _apis/build/retention 
into the PATCH _apis/build/retention body property names.

.DESCRIPTION
Below are the GET & PATCH _apis/build/retention request/respones. 

Notice the GET and PATCH responses are the same, while the PATCH body uses different property names.
This function will convert the GET/PATCH responses to match the PATCH request body properties.

GET _apis/build/retention
--
{
    "purgeArtifacts": { "min": 1, "max": 60, "value": 51 },
    "purgeRuns": { "min": 1, "max": 60, "value": 51 },
    "purgePullRequestRuns": { "min": 1, "max": 60, "value": 51 },
    "retainRunsPerProtectedBranch": null
}

POST _apis/build/retention
Request Body:
{
    "artifactsRetention": { "min": 1, "max": 60, "value": 51 },
    "runRetention": { "min": 1, "max": 60, "value": 51 },
    "pullRequestRunRetention": { "min": 1, "max": 60, "value": 51 },
    "retainRunsPerProtectedBranch": { "min": 1, "max": 60, "value": 51 },
}

Response Body:
{
    "purgeArtifacts": { "min": 1, "max": 60, "value": 51 },
    "purgeRuns": { "min": 1, "max": 60, "value": 51 },
    "purgePullRequestRuns": { "min": 1, "max": 60, "value": 51 },
    "retainRunsPerProtectedBranch": null
}

.NOTES
Research notes aligning UX, GET, PATCH fields:

@{
    # UX Label: Days to keep artifacts, symbols and attachments
    # UX Field: PurgeArtifacts
    # Get Field: purgeArtifacts
    # Patch Field: artifactsRetention 
    purgeArtifacts               = @{
        min   = 1
        max   = 60
        value = 51
    }

    # UX Label: Days to keep runs
    # UX Field: PurgeRuns
    # Get Field: purgeRuns
    # Patch Field: runRetention
    purgeRuns                    = @{
        min   = 30
        max   = 731
        value = 37
    }

    # UX Label: Days to keep pull request runs
    # UX Field: PurgePullRequestRuns
    # Get Field: purgePullRequestRuns
    # Patch Field: pullRequestRunRetention
    purgePullRequestRuns         = @{
        min   = 1
        max   = 30
        value = 4
    }

    # UX Label: Number of recent runs to retain per pipeline
    # UX Help Label: This many runs will also be retained per protected branch and default pipeline branch. (Azure Repos only)
    # UX Field: runsToRetainPerProtectedBranch
    # Get Field: retainRunsPerProtectedBranch
    # Patch Field: retainRunsPerProtectedBranch
    # BUG: Always null on return
    retainRunsPerProtectedBranch = @{
        min   = 0
        max   = 50
        value = 0
    }
}
#>
function ConvertRetentionSettingsGetToPatch {
    [CmdletBinding()]
    [SkipTest('HasOrganizationParameter')]
    param (
        [Parameter(Mandatory)]
        $Response
    )

    $Settings = @{}

    $FieldMap = @{
        'purgeArtifacts'               = 'artifactsRetention'
        'purgeRuns'                    = 'runRetention'
        'purgePullRequestRuns'         = 'pullRequestRunRetention'

        # Note: This field is bugged, it's always NULL on GET/PATCH response, I think its meant to be runsToRetainPerProtectedBranch
        'retainRunsPerProtectedBranch' = 'retainRunsPerProtectedBranch' 
    }
    $Fields = $Response.psobject.Properties | Where-object Name -in $FieldMap.Keys 

    foreach ($Field in $Fields) {
        $Settings.$($FieldMap[$Field.Name]) = $Field.Value.value
    }

    [pscustomobject]$Settings
}
#endregion ConvertRetentionSettingsGetToPatch

#region ConvertRetentionSettingsToPatchBody

<#
.SYNOPSIS
Converts Retention Settings Dictionary<string, int> into RetentionSetting objects

.DESCRIPTION
Converts Retention Settings Dictionary<string, int> into RetentionSetting objects.

.PARAMETER Values
Keyed dictionary of integers

Example:
@{
    artifactsRetention = 51
    runRetention = 51,
    ...
}

.OUTPUTS
@{
    artifactsRetention = @{
        min = 0,
        max = 0,
        value = 51
    },
    runRetention = @{
        min = 0,
        max = 0,
        value = 51
    },
    ...
}
#>
function ConvertRetentionSettingsToPatchBody {
    [CmdletBinding()]
    [SkipTest('HasOrganizationParameter')]
    param (
        [Parameter(Mandatory)]
        $Values
    )

    $Settings = @{}
    if ($Values -is [pscustomobject]) {
        foreach ($ValueProperty in $Values.psobject.Properties) {
            $Settings[$ValueProperty.Name] = @{
                value = $ValueProperty.Value
                min   = $null
                max   = $null
            }
        }
    }
    else {
        foreach ($Value in $Values.GetEnumerator()) {
            $Settings[$Value.key] = @{
                value = $Value.value
                min   = $null
                max   = $null
            }
        }
    }

    [pscustomobject]$Settings
}
#endregion ConvertRetentionSettingsToPatchBody

#region GetADOPSConfigFile

function GetADOPSConfigFile {
    param (
        [Parameter()]
        [string]$ConfigPath = '~/.ADOPS/Config.json'
    )
    
    # Create config if not exists
    if (-not (Test-Path $ConfigPath)) {
        NewADOPSConfigFile
    }
    
    Get-Content $ConfigPath | ConvertFrom-Json -AsHashtable
}
#endregion GetADOPSConfigFile

#region GetADOPSDefaultOrganization

function GetADOPSDefaultOrganization {
    [CmdletBinding()]
    [SkipTest('HasOrganizationParameter')]
    param ()

    $ADOPSConfig = GetADOPSConfigFile

    if ([string]::IsNullOrWhiteSpace($ADOPSConfig['Default']['Organization'])) {
        throw 'No default organization found! Use Connect-ADOPS or set Organization parameter.'
    }
    else {
        Write-Output $ADOPSConfig['Default']['Organization']
    }
}
#endregion GetADOPSDefaultOrganization

#region GetADOPSOrganizationAccess

function GetADOPSOrganizationAccess {
    [CmdletBinding()]
    [SkipTest('HasOrganizationParameter')]
    param (
        [Parameter(Mandatory)]
        [string]$AccountId,
        
        [Parameter()]
        [string]$Token
    )

    (InvokeADOPSRestMethod -Method GET -Token $Token -Uri "https://app.vssps.visualstudio.com/_apis/accounts?memberId=$AccountId&api-version=7.1-preview.1").value.accountName
}
#endregion GetADOPSOrganizationAccess

#region InvokeADOPSRestMethod

function InvokeADOPSRestMethod {
    [SkipTest('HasOrganizationParameter')]
    param (
        [Parameter(Mandatory)]
        [URI]$Uri,

        [Parameter()]
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [string]$ContentType = 'application/json',

        [Parameter()]
        [switch]$FullResponse,

        [Parameter()]
        [string]$OutFile,

        [Parameter()]
        [string]$Token
    )
    
    if (-not $PSBoundParameters.ContainsKey('Token')) {
        $Token = (NewAzToken).Token
    }

    $InvokeSplat = @{
        'Uri'         = $Uri
        'Method'      = $Method
        'Headers'     = @{
            'Authorization' = "Bearer $Token"
        }
        'ContentType' = $ContentType
    }

    if (-not [string]::IsNullOrEmpty($Body)) {
        $InvokeSplat.Add('Body', $Body)
    }

    if ($FullResponse) {
        $InvokeSplat.Add('ResponseHeadersVariable', 'ResponseHeaders')
        $InvokeSplat.Add('StatusCodeVariable', 'ResponseStatusCode')
    }

    if ($OutFile) {
        Write-Debug "$Method $Uri"
        Invoke-RestMethod @InvokeSplat -OutFile $OutFile
    }
    else {
        Write-Debug "$Method $Uri"
        $Result = Invoke-RestMethod @InvokeSplat

        if ($Result -like "*Azure DevOps Services | Sign In*") {
            throw 'Failed to call Azure DevOps API. Please login using Connect-ADOPS before running commands.'
        }
        elseif ($FullResponse) {
            @{ Content = $Result; Headers = $ResponseHeaders; StatusCode = $ResponseStatusCode }
        }
        else {
            $Result
        }
    }
}
#endregion InvokeADOPSRestMethod

#region NewADOPSConfigFile

function NewADOPSConfigFile {
    param (
        [Parameter()]
        [string]$ConfigPath = '~/.ADOPS/Config.json'
    )

    @{
        'Default' = @{}
    } | SetADOPSConfigFile -ConfigPath $ConfigPath
}
#endregion NewADOPSConfigFile

#region NewAzToken

function NewAzToken {
    [CmdletBinding()]
    [SkipTest('HasOrganizationParameter')]
    param ()

    $TokenSplat = @{
        Resource = '499b84ac-1321-427f-aa17-267ca6975798'
    }
    switch ($script:LoginMethod) {
        'Default' {
            try {
                $UserContext = GetADOPSConfigFile

                $TokenSplat['Username'] = $Usercontext['Default']['Identity']
                $TokenSplat['TenantId'] = $Usercontext['Default']['TenantId']
                Get-AzToken @TokenSplat -TokenCache $script:AzTokenCache
            }
            catch {
                # Make sure we present the inner exception to users but with a nicer error message
                if ($_.Exception.GetType().FullName -eq 'Azure.Identity.CredentialUnavailableException') {
                    $Exception = New-Object System.InvalidOperationException "Could not find existing token, please run the command Connect-ADOPS!", $_.Exception
                    $ErrorRecord = New-Object Management.Automation.ErrorRecord $Exception, 'ADOPSGetTokenError', ([System.Management.Automation.ErrorCategory]::InvalidOperation), $null
                    throw $ErrorRecord
                }
                else {
                    throw $_
                }
            }
        }
        'ManagedIdentity' {
            Get-AzToken @TokenSplat -ManagedIdentity
        }
        'OAuthToken' {
            return $Script:ScriptToken
        }
        Default {
            throw 'No login method was set, module file may have been corrupted!'
        }
    }
}
#endregion NewAzToken

#region SetADOPSConfigFile

function SetADOPSConfigFile {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$ConfigPath = '~/.ADOPS/Config.json',

        [Parameter(ValueFromPipeline)]
        [object]$ConfigObject
    )

    $null = New-Item -Path '~/.ADOPS/' -ItemType Directory -ErrorAction SilentlyContinue
    Set-Content -Path $ConfigPath -Value ($ConfigObject | ConvertTo-Json -Compress) -Force
}
#endregion SetADOPSConfigFile

#region SetADOPSPipelinePermission

function SetADOPSPipelinePermission {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [string]$Project,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [switch]$AllPipelines,

        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [int]$PipelineId,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [ResourceType]$ResourceType,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [string]$ResourceId,

        [Parameter(ParameterSetName = 'AllPipelines')]
        [Parameter(ParameterSetName = 'SinglePipeline')]
        [bool]$Authorized = $true,

        [Parameter(ParameterSetName = 'AllPipelines')]
        [Parameter(ParameterSetName = 'SinglePipeline')]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }
    
    $URI = "https://dev.azure.com/${Organization}/${Project}/_apis/pipelines/pipelinepermissions/${ResourceType}/${ResourceId}?api-version=7.1-preview.1"
    $method = 'PATCH'

    $Body = switch ($PSCmdlet.ParameterSetName) {
        'AllPipelines' {
            @{
                allPipelines = @{
                    authorized = $Authorized
                }
            }
        }
        'SinglePipeline' {
            @{
                pipelines = @(
                    [ordered]@{
                        id         = $PipelineId
                        authorized = $Authorized
                    }
                )
            }
        }
        'Default' {
            throw 'Invalid parameter set, this should not happen'
        }
    }
    $Body = $Body | ConvertTo-Json -Depth 10 -Compress

    InvokeADOPSRestMethod -Uri $Uri -Method $Method -Body $Body
}
#endregion SetADOPSPipelinePermission

#region Connect-ADOPS

function Connect-ADOPS {
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Interactive')]
        [Parameter(Mandatory, ParameterSetName = 'ManagedIdentity')]
        [Parameter(Mandatory, ParameterSetName = 'OAuthToken')]
        [string]$Organization,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [Parameter(ParameterSetName = 'OAuthToken')]
        [string]$TenantId,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [Parameter(ParameterSetName = 'OAuthToken')]
        [switch]$SkipVerification,

        [Parameter(ParameterSetName = 'Interactive')]
        [switch]$Interactive,

        [Parameter(Mandatory, ParameterSetName = 'ManagedIdentity')]
        [switch]$ManagedIdentity,

        [Parameter(Mandatory, ParameterSetName = 'OAuthToken')]
        [String]$OAuthToken
    )
    
    $TokenSplat = @{
        Resource = '499b84ac-1321-427f-aa17-267ca6975798'
        Scope    = '.default'
    }

    # Add TenantId if provided
    if ($PSBoundParameters.ContainsKey('TenantId')) {
        $TokenSplat.Add('TenantId', $TenantId)
    }

    switch ($PSCmdlet.ParameterSetName) {
        'OAuthToken' {
            $script:LoginMethod = 'OAuthToken'
            $script:ScriptToken = @{
                Token = $OAuthToken
            }
            $Token = $OAuthToken
            $TokenTenantId = 'NotSpecified'
            $TokenIdentity = $null
        }
        'ManagedIdentity' {
            $TokenSplat.Add('ManagedIdentity', $true)
            $script:LoginMethod = 'ManagedIdentity'

            $Token = Get-AzToken @TokenSplat
            $TokenTenantId = $Token.TenantId
            $TokenIdentity = $Token.Identity
        }
        'Interactive' {
            $TokenSplat.Add('TokenCache', $script:AzTokenCache)
            $TokenSplat.Add('Interactive', $true)

            $Token = Get-AzToken @TokenSplat
            $TokenTenantId = $Token.TenantId
            $TokenIdentity = $Token.Identity
        }
    }

    if ($Organization -like "https://dev.azure.com/*") {
        $Organization = ($Organization -split "/")[3]
    }
    
    if (-not $PSBoundParameters.ContainsKey('SkipVerification')) {
        # Get User context
        $Me = InvokeADOPSRestMethod -Method GET -Token $Token -Uri 'https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=7.1-preview.3'
    
        # Get available orgs
        $Orgs = GetADOPSOrganizationAccess -AccountId $Me.publicAlias -Token $Token
    
        if ($Organization -notin $Orgs) {
            throw "The connected account does not have access to the organization '$Organization'. Organizations available: $($Orgs -join ",")`nAre you connected to the correct tennant? $TokenTenantId"
        }
    }
    else {
        Write-Verbose 'Skipping organization access verification.'
        $Me = @{ id = 'unverified' }
    }

    # If user provided a token, we have not parsed the JWT for the email/id
    if ($null -eq $TokenIdentity) {
        # Instead take info from the DevOps response
        if (-not [string]::IsNullOrWhiteSpace($Me.emailAddress)) {
            $TokenIdentity = $Me.emailAddress 
        }
        else {
            $TokenIdentity = $Me.id
        }
    }
    
    $ADOPSConfig = GetADOPSConfigFile
    $ADOPSConfig['Default'] = @{
        'Identity'     = $TokenIdentity
        'TenantId'     = $TokenTenantId
        'Organization' = $Organization
    }

    SetADOPSConfigFile -ConfigObject $ADOPSConfig
    
    Write-Output $ADOPSConfig['Default']
}
#endregion Connect-ADOPS

#region Disconnect-ADOPS

function Disconnect-ADOPS {
    [CmdletBinding()]
    [SkipTest('HasOrganizationParameter')]
    param ()

    # Reset context
    NewADOPSConfigFile

    Clear-AzTokenCache -TokenCache $script:AzTokenCache
}
#endregion Disconnect-ADOPS

#region Get-ADOPSAgentQueue

function Get-ADOPSAgentQueue {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [string]$QueueName
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }
    
    
    if ($PSBoundParameters.ContainsKey('QueueName')) {
        $Uri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/queues?queueName=${QueueName}&api-version=7.1"
    }
    else {
        $Uri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/queues?api-version=7.1"
    }
    
    $Method = 'GET'
    $Queue = InvokeADOPSRestMethod -Uri $Uri -Method $Method -Body $Body
    
    if ($Queue.psobject.properties.name -contains 'value') {
        Write-Output $Queue.value
    }
    else {
        Write-Output $Queue
    }
}
#endregion Get-ADOPSAgentQueue

#region Get-ADOPSArtifactFeed

function Get-ADOPSArtifactFeed {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'FeedId', Mandatory)]
        [string]$Project,
        
        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'FeedId')]
        [string]$Organization,

        [Parameter(ParameterSetName = 'FeedId', Mandatory)]
        [Alias('Name')]
        [string]$FeedId
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }
    
    $Uri = "https://feeds.dev.azure.com/${Organization}"
    if (-not ([string]::IsNullOrEmpty($Project))) {
        $Uri = "${Uri}/${Project}"
    }
    $Uri = "${Uri}/_apis/packaging/feeds"
    if (-not ([string]::IsNullOrEmpty($FeedId))) {
        $Uri = "${Uri}/${FeedId}"
    }
    $Uri = "${Uri}?api-version=7.2-preview.1"
    
    $Method = 'Get'

    $InvokeSplat = @{
        Uri    = $Uri
        Method = $Method
    }

    $res = InvokeADOPSRestMethod @InvokeSplat
    if ( 
        (($res | Get-Member -MemberType NoteProperty).Name -contains 'count') -and 
        (($res | Get-Member -MemberType NoteProperty).Name -contains 'value')
    ) {
        Write-Output $res.value -NoEnumerate
    }
    else {
        Write-Output $res
    }
}
#endregion Get-ADOPSArtifactFeed

#region Get-ADOPSAuditActions

function Get-ADOPSAuditActions {
    param (
        [Parameter()]
        [string]$Organization
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    (InvokeADOPSRestMethod -Uri "https://auditservice.dev.azure.com/$Organization/_apis/audit/actions" -Method Get).value
}
#endregion Get-ADOPSAuditActions

#region Get-ADOPSAuditStreams

function Get-ADOPSAuditStreams {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    (InvokeADOPSRestMethod -Uri "https://auditservice.dev.azure.com/$Organization/_apis/audit/streams" -Method Get).value
}
#endregion Get-ADOPSAuditStreams

#region Get-ADOPSBuildDefinition

function Get-ADOPSBuildDefinition {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [string]$Organization,
        
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter()]
        [int]$Id
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if ($PSBoundParameters.ContainsKey('Id')) {
        [int[]]$idList = $id
    }
    else {
        [int[]]$idList = (InvokeADOPSRestMethod -Method GET -Uri "https://dev.azure.com/${Organization}/${Project}/_apis/build/definitions?api-version=7.2-preview.7").value.id
    }

    [array]$res = @()
    foreach ($definition in $idList) {
        [array]$res += InvokeADOPSRestMethod -Method GET -Uri "https://dev.azure.com/${Organization}/${Project}/_apis/build/definitions/${definition}?api-version=7.2-preview.7"
    }

    Write-Output $res -NoEnumerate
}
#endregion Get-ADOPSBuildDefinition

#region Get-ADOPSConnection

function Get-ADOPSConnection {
    [SkipTest('HasOrganizationParameter')]
    param ()
    
    $res = GetADOPSConfigFile
    $res['Default']
}
#endregion Get-ADOPSConnection

#region Get-ADOPSElasticPool

function Get-ADOPSElasticPool {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int32]$PoolId,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if ($PSBoundParameters.ContainsKey('PoolId')) {
        $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/elasticpools/$PoolId`?api-version=7.1-preview.1"
    }
    else {
        $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/elasticpools?api-version=7.1-preview.1"
    }
    
    $Method = 'GET'
    $ElasticPoolInfo = InvokeADOPSRestMethod -Uri $Uri -Method $Method -Body $Body
    if ($ElasticPoolInfo.psobject.properties.name -contains 'value') {
        Write-Output $ElasticPoolInfo.value
    }
    else {
        Write-Output $ElasticPoolInfo
    }
}
#endregion Get-ADOPSElasticPool

#region Get-ADOPSFileContent

function Get-ADOPSFileContent {
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(Mandatory)]
        [string]$RepositoryId,

        [Parameter(Mandatory)]
        [string]$FilePath
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if (-Not $FilePath.StartsWith('/')) {
        $FilePath = $FilePath.Insert(0, '/')
    }

    $UrlEncodedFilePath = [System.Web.HttpUtility]::UrlEncode($FilePath)
    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/items?path=$UrlEncodedFilePath&api-version=7.1-preview.1"

    InvokeADOPSRestMethod -Uri $Uri -Method Get
}
#endregion Get-ADOPSFileContent

#region Get-ADOPSGroup

function Get-ADOPSGroup {
    param ([Parameter()]
        [string]$Organization,

        [Parameter()]
        [string]
        $Descriptor,

        [Parameter(DontShow)]
        [string]$ContinuationToken
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if ($PSBoundParameters.ContainsKey('Descriptor')) {
        $Uri = "https://vssps.dev.azure.com/$Organization/_apis/graph/groups/$Descriptor`?api-version=7.2-preview.1"

        $Response = InvokeADOPSRestMethod -Uri $Uri -Method 'GET'

        return $Response
    }
    else {
        if (-not [string]::IsNullOrEmpty($ContinuationToken)) {
            $Uri = "https://vssps.dev.azure.com/$Organization/_apis/graph/groups?continuationToken=$ContinuationToken&api-version=7.1-preview.1"
        }
        else {
            $Uri = "https://vssps.dev.azure.com/$Organization/_apis/graph/groups?api-version=7.1-preview.1"
        }
    }
    
    $Method = 'GET'

    $Response = InvokeADOPSRestMethod -FullResponse -Uri $Uri -Method $Method

    $Groups = $Response.Content.value
    Write-Verbose "Found $($Response.Content.count) groups"

    if ($Response.Headers.ContainsKey('X-MS-ContinuationToken')) {
        Write-Verbose "Found continuationToken. Will fetch more groups."
        $parameters = [hashtable]$PSBoundParameters
        $parameters.Add('ContinuationToken', $Response.Headers['X-MS-ContinuationToken']?[0])
        $Groups += Get-ADOPSGroup @parameters
    }
    
    Write-Output $Groups
}

#endregion Get-ADOPSGroup

#region Get-ADOPSNode

function Get-ADOPSNode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int32]$PoolId,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/elasticpools/$PoolId/nodes?api-version=7.1-preview.1"

    $Method = 'GET'
    $NodeInfo = InvokeADOPSRestMethod -Uri $Uri -Method $Method

    if ($NodeInfo.psobject.properties.name -contains 'value') {
        Write-Output $NodeInfo.value
    }
    else {
        Write-Output $NodeInfo
    }
}
#endregion Get-ADOPSNode

#region Get-ADOPSOrganizationAdminOverview

function Get-ADOPSOrganizationAdminOverview {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter()]
        [string[]]
        $ContributionIds = @("ms.vss-admin-web.organization-admin-overview-delay-load-data-provider")
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Body = @{
        'contributionIds' = $ContributionIds
    } | ConvertTo-Json -Depth 100

    $Uri = "https://dev.azure.com/$Organization/_apis/Contribution/HierarchyQuery?api-version=7.2-preview"

    $Response = InvokeADOPSRestMethod -Uri $Uri -Method Post -Body $Body

    if ($Response.dataProviderExceptions) {
        $Response.dataProviderExceptions
    }
    else {
        $Response.dataProviders
    }

}
#endregion Get-ADOPSOrganizationAdminOverview

#region Get-ADOPSOrganizationAdvancedSecurity

function Get-ADOPSOrganizationAdvancedSecurity {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://advsec.dev.azure.com/$Organization/_apis/Management/enablement"

    (InvokeADOPSRestMethod -Uri $Uri -Method Get)
}
#endregion Get-ADOPSOrganizationAdvancedSecurity

#region Get-ADOPSOrganizationCommerceMeterUsage

function Get-ADOPSOrganizationCommerceMeterUsage {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter()]
        [string]$MeterId
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }


    $AccountId = (InvokeADOPSRestMethod -Method GET -Uri 'https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=7.1-preview.3').publicAlias
    
    # GetADOPSOrganizationAccess could have been used instead.
    # However it requires token and only returns accountName

    # Get available orgs
    $Orgs = (InvokeADOPSRestMethod -Method GET -Uri "https://app.vssps.visualstudio.com/_apis/accounts?memberId=$AccountId&api-version=7.1-preview.1").value
    
    $OrganizationId = ($Orgs | Where-object accountName -eq $Organization).AccountId
    
    if ($PSBoundParameters.ContainsKey('MeterId')) {
        InvokeADOPSRestMethod -Uri "https://azdevopscommerce.dev.azure.com/$OrganizationId/_apis/AzComm/MeterUsage2/$MeterId" -Method Get
    }
    else {
        (InvokeADOPSRestMethod -Uri "https://azdevopscommerce.dev.azure.com/$OrganizationId/_apis/AzComm/MeterUsage2" -Method Get).value
    }

}
#endregion Get-ADOPSOrganizationCommerceMeterUsage

#region Get-ADOPSOrganizationPipelineSettings

function Get-ADOPSOrganizationPipelineSettings {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Body = '{
        "contributionIds": [
            "ms.vss-build-web.pipelines-org-settings-data-provider"
        ]
    }'

    $Uri = "https://dev.azure.com/$Organization/_apis/Contribution/HierarchyQuery?api-version=7.1-preview"

    (InvokeADOPSRestMethod -Uri $Uri -Method Post -Body $Body).dataProviders.'ms.vss-build-web.pipelines-org-settings-data-provider'

}
#endregion Get-ADOPSOrganizationPipelineSettings

#region Get-ADOPSOrganizationPolicy

function Get-ADOPSOrganizationPolicy {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter()]
        [ValidateSet(
            'Security',
            'Privacy',
            'ApplicationConnection',
            'User'
        )]
        [string]
        $PolicyCategory
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/_settings/organizationPolicy?__rt=fps&__ver=2"
    $Data = InvokeADOPSRestMethod -Uri $Uri -Method Get
    if ($PSBoundParameters.ContainsKey('PolicyCategory')) {
        switch ($PolicyCategory) {
            'Security' {
                $Policies = $Data.fps.dataProviders.data.'ms.vss-admin-web.organization-policies-data-provider'.policies.security
            }
            'Privacy' {
                $Policies = $Data.fps.dataProviders.data.'ms.vss-admin-web.organization-policies-data-provider'.policies.privacy
            }
            'ApplicationConnection' {
                $Policies = $Data.fps.dataProviders.data.'ms.vss-admin-web.organization-policies-data-provider'.policies.applicationConnection
            }
            'User' {
                $Policies = $Data.fps.dataProviders.data.'ms.vss-admin-web.organization-policies-data-provider'.policies.user
            }
        }
    }
    else {
        $Policies = $Data.fps.dataProviders.data.'ms.vss-admin-web.organization-policies-data-provider'.policies.psobject.Properties.name | ForEach-Object {
            $Data.fps.dataProviders.data.'ms.vss-admin-web.organization-policies-data-provider'.policies.$_.policy
        }
    }

    Write-Output $Policies
}
#endregion Get-ADOPSOrganizationPolicy

#region Get-ADOPSOrganizationRepositorySettings

function Get-ADOPSOrganizationRepositorySettings {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Body = '{
        "contributionIds": [
            "ms.vss-build-web.pipelines-org-settings-data-provider"
        ]
    }'

    $Uri = "https://dev.azure.com/$Organization/_api/_versioncontrol/AllGitRepositoriesOptions?__v=5"

    (InvokeADOPSRestMethod -Uri $Uri -Method Get).__wrappedArray

}
#endregion Get-ADOPSOrganizationRepositorySettings

#region Get-ADOPSPipeline

function Get-ADOPSPipeline {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [int]$Revision,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/pipelines?api-version=7.1-preview.1"
    
    $InvokeSplat = @{
        Method = 'Get'
        Uri    = $URI
    }

    $AllPipelines = (InvokeADOPSRestMethod @InvokeSplat).value

    if ($PSBoundParameters.ContainsKey('Name')) {
        $Pipelines = $AllPipelines | Where-Object { $_.name -eq $Name }
        if (-not $Pipelines) {
            throw "The specified PipelineName $Name was not found amongst pipelines: $($AllPipelines.name -join ', ')!" 
        } 
    }
    else {
        $Pipelines = $AllPipelines
    }

    $return = @()

    foreach ($Pipeline in $Pipelines) {

        $pipelineRevision = [Uri]::EscapeDataString($PSBoundParameters.ContainsKey('Revision') ? $Revision : $Pipeline.revision)
        $pipelineUrl = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/$($Pipeline.id)?api-version=7.1-preview.1&pipelineVersion=$pipelineRevision"

        $InvokeSplat = @{
            Method = 'Get'
            Uri    = $pipelineUrl
        }
    
        $result = InvokeADOPSRestMethod @InvokeSplat

        $return += $result
    }

    return $return
}

#endregion Get-ADOPSPipeline

#region Get-ADOPSPipelineRetentionSettings

function Get-ADOPSPipelineRetentionSettings {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/build/retention?api-version=7.2-preview.1"
    $Response = InvokeADOPSRestMethod -Uri $Uri -Method Get

    $Settings = ConvertRetentionSettingsGetToPatch -Response $Response

    Write-Output $Settings
}
#endregion Get-ADOPSPipelineRetentionSettings

#region Get-ADOPSPipelineSettings

function Get-ADOPSPipelineSettings {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/build/generalsettings?api-version=7.1-preview.1"
    $Settings = InvokeADOPSRestMethod -Uri $Uri -Method Get

    Write-Output $Settings
}
#endregion Get-ADOPSPipelineSettings

#region Get-ADOPSPipelineTask

function Get-ADOPSPipelineTask {
    param (
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string]$Organization,

        [Parameter()]
        [int]$Version
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/tasks?api-version=7.1-preview.1"

    $result = InvokeADOPSRestMethod -Uri $Uri -Method Get

    $ReturnValue = $result | ConvertFrom-Json -AsHashtable | Select-Object -ExpandProperty value

    if (-Not [string]::IsNullOrEmpty($Name)) {
        $ReturnValue = $ReturnValue |  Where-Object -Property name -EQ $Name
    }
    if ($Version) {
        $ReturnValue = $ReturnValue |  Where-Object -FilterScript { $_.version.major -eq $Version }
    }

    $ReturnValue
}
#endregion Get-ADOPSPipelineTask

#region Get-ADOPSPool

function Get-ADOPSPool {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'PoolId')]
        [int32]$PoolId,

        [Parameter(Mandatory, ParameterSetName = 'PoolName')]
        [string]$PoolName,

        # Include legacy pools
        [Parameter(ParameterSetName = 'All')]
        [switch]$IncludeLegacy,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    switch ($PSCmdlet.ParameterSetName) {
        'PoolId' { $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/pools/$PoolId`?api-version=7.1-preview.1" }
        'PoolName' { $uri = "https://dev.azure.com/$Organization/_apis/distributedtask/pools?poolName=$PoolName`&api-version=7.1-preview.1" }
        'All' { $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/pools?api-version=7.1-preview.1" }
    }
    
    $Method = 'GET'
    $PoolInfo = InvokeADOPSRestMethod -Uri $Uri -Method $Method

    if ($PoolInfo.psobject.properties.name -contains 'value') {
        $PoolInfo = $PoolInfo.value
    }
    if ((-not ($IncludeLegacy.IsPresent)) -and $PSCmdlet.ParameterSetName -eq 'All') {
        $PoolInfo = $PoolInfo | Where-Object { $_.IsLegacy -eq $false }
    }
    Write-Output $PoolInfo
}
#endregion Get-ADOPSPool

#region Get-ADOPSProject

function Get-ADOPSProject {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'ByName')]
        [Parameter(ParameterSetName = 'ById')]
        [string]$Organization,

        [Parameter(ParameterSetName = 'ByName')]
        [Alias('Project')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById')]
        [string]$Id

    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"

    $Method = 'GET'
    $ProjectInfo = (InvokeADOPSRestMethod -Uri $Uri -Method $Method).value

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $ProjectInfo = $ProjectInfo | Where-Object -Property Name -eq $Name
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
        $ProjectInfo = $ProjectInfo | Where-Object -Property Id -eq $Id
    }

    Write-Output $ProjectInfo
}
#endregion Get-ADOPSProject

#region Get-ADOPSRepository

function Get-ADOPSRepository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter()]
        [string]$Repository,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if ($PSBoundParameters.ContainsKey('Repository')) {
        $Uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$Repository`?api-version=7.1-preview.1"
    }
    else {
        $Uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.1-preview.1"
    }
    
    try {
        $result = InvokeADOPSRestMethod -Uri $Uri -Method Get
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        $ErrorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
        if ($ErrorMessage.message -like "TF401019:*") {
            Write-Verbose "The Git repository with name or identifier $Repository does not exist or you do not have permissions for the operation you are attempting."
            $result = $null
        }
        elseif ($ErrorMessage.message -like "TF200016:*") {
            Write-Verbose "The following project does not exist: $Project. Verify that the name of the project is correct and that the project exists on the specified Azure DevOps Server."
            $result = $null
        }
        else {
            Throw $_
        }
    }

    if ($result.psobject.properties.name -contains 'value') {
        Write-Output -InputObject $result.value
    }
    else {
        Write-Output -InputObject $result
    }
}
#endregion Get-ADOPSRepository

#region Get-ADOPSResourceUsage

function Get-ADOPSResourceUsage {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    (InvokeADOPSRestMethod -Uri "https://dev.azure.com/$Organization/_apis/ResourceUsage" -Method Get).value
}
#endregion Get-ADOPSResourceUsage

#region Get-ADOPSServiceConnection

function Get-ADOPSServiceConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,
        
        [Parameter()]
        [switch]
        $IncludeFailed
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints?includeFailed=$IncludeFailed&api-version=7.1-preview.4"
    
    $InvokeSplat = @{
        Method = 'Get'
        Uri    = $URI
    }

    $ServiceConnections = (InvokeADOPSRestMethod @InvokeSplat).value

    if ($PSBoundParameters.ContainsKey('Name')) {
        $ServiceConnection = $ServiceConnections | Where-Object { $_.name -eq $Name }
        if (-not $ServiceConnection) {
            throw "The specified ServiceConnectionName $Name was not found amongst Connections: $($ServiceConnections.name -join ', ')!" 
        }
        return $ServiceConnection
    }
    else {
        return $ServiceConnections
    }

}
#endregion Get-ADOPSServiceConnection

#region Get-ADOPSUsageData

function Get-ADOPSUsageData {
    param(
        [Parameter()]
        [ValidateSet('Private', 'Public')]
        [string]$ProjectVisibility = 'Public',

        [Parameter()]
        [Switch]$SelfHosted,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if ($SelfHosted.IsPresent) {
        $Hosted = $false
    }
    else {
        $Hosted = $true
    }

    $URI = "https://dev.azure.com/$Organization/_apis/distributedtask/resourceusage?parallelismTag=${ProjectVisibility}&poolIsHosted=${Hosted}&includeRunningRequests=true"
    $Method = 'Get'
    
    $InvokeSplat = @{
        Method = $Method
        Uri    = $URI
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion Get-ADOPSUsageData

#region Get-ADOPSUser

function Get-ADOPSUser {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'Descriptor', Position = 0)]
        [string]$Descriptor,

        [Parameter()]
        [string]$Organization,

        [Parameter(ParameterSetName = 'Default', DontShow)]
        [string]$ContinuationToken
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if ($PSCmdlet.ParameterSetName -eq 'Default') {
        $Uri = "https://vssps.dev.azure.com/$Organization/_apis/graph/users?api-version=7.1-preview.1"
        $Method = 'GET'
        if (-not [string]::IsNullOrEmpty($ContinuationToken)) {
            $Uri += "&continuationToken=$ContinuationToken"
        }
        $Response = (InvokeADOPSRestMethod -FullResponse -Uri $Uri -Method $Method)
        $Users = $Response.Content.value
        Write-Verbose "Found $($Response.Content.count) users"

        if ($Response.Headers.ContainsKey('X-MS-ContinuationToken')) {
            Write-Verbose "Found continuationToken. Will fetch more users."
            $parameters = [hashtable]$PSBoundParameters
            $parameters.Add('ContinuationToken', $Response.Headers['X-MS-ContinuationToken']?[0])
            $Users += Get-ADOPSUser @parameters
        }   
        Write-Output $Users
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Name') {
        $Uri = "https://vsaex.dev.azure.com/$Organization/_apis/UserEntitlements?`$filter=name eq '$Name'&`$orderBy=name Ascending&api-version=7.1-preview.3"
        $Method = 'GET'
        $Users = (InvokeADOPSRestMethod -Uri $Uri -Method $Method).members.user
        if ($null -eq $Users) {
            Get-ADOPSUser | Where-Object -Property displayName -eq $Name
        }
        Write-Output $Users
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Descriptor') {
        $Uri = "https://vssps.dev.azure.com/$Organization/_apis/graph/users/$Descriptor`?api-version=7.1-preview.1"
        $Method = 'GET'
        $User = (InvokeADOPSRestMethod -Uri $Uri -Method $Method)
        Write-Output $User
    }
}
#endregion Get-ADOPSUser

#region Get-ADOPSVariableGroup

function Get-ADOPSVariableGroup {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'Name')]
        [Parameter(ParameterSetName = 'Id')]
        [string]$Organization,
        
        [Parameter(Mandatory, ParameterSetName = 'All')]
        [Parameter(Mandatory, ParameterSetName = 'Name')]
        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [string]$Project,
        
        [Parameter(ParameterSetName = 'Name')]
        [string]$Name,
        
        [Parameter(ParameterSetName = 'Id')]
        [int]$Id
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Method = 'Get'

    if ($PSCmdlet.ParameterSetName -eq 'Name') {
        $Uri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/variablegroups?groupName=$Name&api-version=7.2-preview.2"
    }
    else {
        $Uri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/variablegroups?api-version=7.2-preview.2"
    }

    $InvokeSplat = @{
        Uri    = $Uri
        Method = $Method
    }

    $result = (InvokeADOPSRestMethod @InvokeSplat).value

    if ($PSCmdlet.ParameterSetName -eq 'Id') {
        $result = $result.Where({ $_.Id -eq $Id })
    }

    Write-Output $result
}
#endregion Get-ADOPSVariableGroup

#region Get-ADOPSWiki

function Get-ADOPSWiki {
    param (
        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter()]
        [string]$WikiId,

        [Parameter()]
        [string]$Organization
    )
 
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $BaseUri = "https://dev.azure.com/$Organization/$Project/_apis/wiki/wikis"
    
    if ($WikiId) {
        $Uri = "${BaseUri}/${WikiId}?api-version=7.1-preview.2"
    }
    else {
        $Uri = "${BaseUri}?api-version=7.1-preview.2"
    }

    $Method = 'Get'

    $res = InvokeADOPSRestMethod -Uri $URI -Method $Method
    
    if ($res.psobject.properties.name -contains 'value') {
        Write-Output -InputObject $res.value
    }
    else {
        Write-Output -InputObject $res
    }
}
#endregion Get-ADOPSWiki

#region Grant-ADOPSPipelinePermission

function Grant-ADOPSPipelinePermission {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [string]$Project,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [switch]$AllPipelines,

        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [int]$PipelineId,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [ResourceType]$ResourceType,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [string]$ResourceId,

        [Parameter(ParameterSetName = 'AllPipelines')]
        [Parameter(ParameterSetName = 'SinglePipeline')]
        [string]$Organization
    )

    SetADOPSPipelinePermission @PSBoundParameters -Authorized $true
}
#endregion Grant-ADOPSPipelinePermission

#region Import-ADOPSRepository

function Import-ADOPSRepository {
    [CmdLetBinding(DefaultParameterSetName = 'RepositoryName')]
    param (
        [Parameter(Mandatory)]
        [string]$GitSource,

        [Parameter(Mandatory, ParameterSetName = 'RepositoryId')]
        [string]$RepositoryId,
        
        [Parameter(Mandatory, ParameterSetName = 'RepositoryName')]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter()]
        [string]$Organization,

        [Parameter()]
        [switch]$Wait
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    switch ($PSCmdlet.ParameterSetName) {
        'RepositoryName' { $RepoIdentifier = $RepositoryName }
        'RepositoryId' { $RepoIdentifier = $RepositoryId }
        Default {}
    }
    $InvokeSplat = @{
        URI    = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepoIdentifier/importRequests?api-version=7.1-preview.1"
        Method = 'Post'
        Body   = "{""parameters"":{""gitSource"":{""url"":""$GitSource""}}}"
    }

    $repoImport = InvokeADOPSRestMethod @InvokeSplat

    if ($PSBoundParameters.ContainsKey('Wait')) {
        # There appears to be a bug in this API where sometimes you don't get the correct status Uri back. Fix it by constructing a correct one instead.
        $verifyUri = "https://dev.azure.com/$Organization/$Project/_apis$($repoImport.url.Split('_apis')[1])"
        while ($repoImport.status -ne 'completed') {
            $repoImport = InvokeADOPSRestMethod -Uri $verifyUri -Method Get
            Start-Sleep -Seconds 1
        }
    }

    $repoImport
}
#endregion Import-ADOPSRepository

#region Initialize-ADOPSRepository

function Initialize-ADOPSRepository {
    [CmdletBinding()]
    [SkipTest('HasOrganizationParameter')]
    param (
        [Parameter()]
        [string]$Message = 'Repo initialized using ADOPS module.',
        
        [Parameter()]
        [string]$Branch = 'Main',

        [Parameter(Mandatory)]
        [string]$RepositoryId,
        
        [Parameter()]
        [ValidateSet('Actionscript.gitignore', 'Ada.gitignore', 'Agda.gitignore', 'Android.gitignore', 'AppceleratorTitanium.gitignore', 'AppEngine.gitignore', 'ArchLinuxPackages.gitignore', 'Autotools.gitignore', 'C++.gitignore', 'C.gitignore', 'CakePHP.gitignore', 'CFWheels.gitignore', 'ChefCookbook.gitignore', 'Clojure.gitignore', 'CMake.gitignore', 'CodeIgniter.gitignore', 'CommonLisp.gitignore', 'Composer.gitignore', 'Concrete5.gitignore', 'Coq.gitignore', 'CraftCMS.gitignore', 'CUDA.gitignore', 'D.gitignore', 'Dart.gitignore', 'Delphi.gitignore', 'DM.gitignore', 'Drupal.gitignore', 'Eagle.gitignore', 'Elisp.gitignore', 'Elixir.gitignore', 'Elm.gitignore', 'EPiServer.gitignore', 'Erlang.gitignore', 'ExpressionEngine.gitignore', 'ExtJs.gitignore', 'Fancy.gitignore', 'Finale.gitignore', 'ForceDotCom.gitignore', 'Fortran.gitignore', 'FuelPHP.gitignore', 'gcov.gitignore', 'GitBook.gitignore', 'Go.gitignore', 'Godot.gitignore', 'Gradle.gitignore', 'Grails.gitignore', 'GWT.gitignore', 'Haskell.gitignore', 'Idris.gitignore', 'IGORPro.gitignore', 'Java.gitignore', 'Jboss.gitignore', 'Jekyll.gitignore', 'JENKINS_HOME.gitignore', 'Joomla.gitignore', 'Julia.gitignore', 'KiCAD.gitignore', 'Kohana.gitignore', 'Kotlin.gitignore', 'LabVIEW.gitignore', 'Laravel.gitignore', 'Leiningen.gitignore', 'LemonStand.gitignore', 'Lilypond.gitignore', 'Lithium.gitignore', 'Lua.gitignore', 'Magento.gitignore', 'Maven.gitignore', 'Mercury.gitignore', 'MetaProgrammingSystem.gitignore', 'nanoc.gitignore', 'Nim.gitignore', 'Node.gitignore', 'Objective-C.gitignore', 'OCaml.gitignore', 'Opa.gitignore', 'opencart.gitignore', 'OracleForms.gitignore', 'Packer.gitignore', 'Perl.gitignore', 'Phalcon.gitignore', 'PlayFramework.gitignore', 'Plone.gitignore', 'Prestashop.gitignore', 'Processing.gitignore', 'PureScript.gitignore', 'Python.gitignore', 'Qooxdoo.gitignore', 'Qt.gitignore', 'R.gitignore', 'Rails.gitignore', 'Raku.gitignore', 'RhodesRhomobile.gitignore', 'ROS.gitignore', 'Ruby.gitignore', 'Rust.gitignore', 'Sass.gitignore', 'Scala.gitignore', 'Scheme.gitignore', 'SCons.gitignore', 'Scrivener.gitignore', 'Sdcc.gitignore', 'SeamGen.gitignore', 'SketchUp.gitignore', 'Smalltalk.gitignore', 'stella.gitignore', 'SugarCRM.gitignore', 'Swift.gitignore', 'Symfony.gitignore', 'SymphonyCMS.gitignore', 'Terraform.gitignore', 'TeX.gitignore', 'Textpattern.gitignore', 'TurboGears2.gitignore', 'Typo3.gitignore', 'Umbraco.gitignore', 'Unity.gitignore', 'UnrealEngine.gitignore', 'VisualStudio.gitignore', 'VVVV.gitignore', 'Waf.gitignore', 'WordPress.gitignore', 'Xojo.gitignore', 'Yeoman.gitignore', 'Yii.gitignore', 'ZendFramework.gitignore', 'Zephir.gitignore')]
        [string[]]$NewContentTemplate,

        [Parameter()]
        [switch]$Readme,

        [Parameter()]
        [string]$Path,

        [Parameter()]
        [string]$Content = 'Repo initialized using ADOPS module.'
    )
 
    $Organization = GetADOPSDefaultOrganization
    
    $Uri = "https://dev.azure.com/$Organization/_apis/git/repositories/$RepositoryId/pushes?api-version=7.2-preview.3"

    if ($Branch -notmatch '^refs/.*') {
        $Branch = 'refs/heads/' + $Branch
    }

    $changes = @()
    
    if ($Readme -or ( [String]::IsNullOrEmpty($Path) -and ($newContentTemplate.Count -eq 0) )) {
        $changes += @{
            changeType         = 1
            item               = @{path = "/README.md" }
            newContentTemplate = @{
                name = "README.md"
                type = "readme"
            }
        }
    }

    if (-not ([string]::IsNullOrEmpty($Path))) {
        $changes += @{
            changeType = "add"
            item       = @{
                path = $Path
            }
            newContent = @{
                content     = $Content
                contentType = "rawtext"
            }
        }
    }

    if ($newContentTemplate.Count -eq 1) {
        $changes += @{
            changeType         = 1
            item               = @{path = "/.gitignore" }
            newContentTemplate = @{
                name = $newContentTemplate[0]
                type = 'gitignore'
            }
        }
    }

    if ($newContentTemplate.Count -gt 1) {
        foreach ($t in $newContentTemplate) {
            $changes += @{
                changeType         = 1
                item               = @{path = "/$t" }
                newContentTemplate = @{
                    name = $t
                    type = 'gitignore'
                }
            }
        }
    }

    $Body = @{
        commits    = @(
            @{
                comment = $Message
                changes = $changes
            }
        )
        refUpdates = @(
            @{
                name        = $Branch.ToLower()
                oldObjectId = "0000000000000000000000000000000000000000"
            }
        )
    }




    $InvokeSplat = @{
        Uri    = $Uri
        Method = 'Post'
        Body   = $Body | ConvertTo-Json -Compress -Depth 100
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion Initialize-ADOPSRepository

#region Invoke-ADOPSRestMethod

function Invoke-ADOPSRestMethod {
    [SkipTest('HasOrganizationParameter')]
    param (
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = 'Get',

        [Parameter()]
        [string]$Body
    )

    If ( ($Uri -NotLike "*dev.azure.com*") -and ($Uri -NotLike "*visualstudio.com*")) {
        $Organization = GetADOPSDefaultOrganization
        $Uri = "https://dev.azure.com/$Organization/$Uri"
    }

    $InvokeSplat = @{
        Uri    = $Uri
        Method = $Method
    }

    if (-Not [String]::IsNullOrEmpty($Body)) {
        $InvokeSplat.Add('Body', $Body)
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion Invoke-ADOPSRestMethod

#region New-ADOPSArtifactFeed

function New-ADOPSArtifactFeed {
    param (    
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [Alias('UpstreamEnabled')]
        [switch]$IncludeUpstream
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://feeds.dev.azure.com/$Organization/$Project/_apis/packaging/feeds?api-version=7.2-preview.1"

    $body = [ordered]@{
        name                       = $name
        upstreamEnabled            = $IncludeUpstream.IsPresent
        hideDeletedPackageVersions = $true
        project                    = @{
            visibility = 'Private'
        }
    }

    if (-not [string]::IsNullOrEmpty($Description)) {
        $body.Add('description', $Description)
    }

    if ($IncludeUpstream.IsPresent) {
        $upstreamSources = @(
            @{
                name               = "npmjs"
                protocol           = "npm"
                location           = "https://registry.npmjs.org/"
                displayLocation    = "https://registry.npmjs.org/"
                upstreamSourceType = "public"
                status             = "ok"
            }
            @{
                name               = "NuGet Gallery"
                protocol           = "nuget"
                location           = "https://api.nuget.org/v3/index.json"
                displayLocation    = "https://api.nuget.org/v3/index.json"
                upstreamSourceType = "public"
                status             = "ok"
            }
            @{
                name               = "PowerShell Gallery"
                protocol           = "nuget"
                location           = "https://www.powershellgallery.com/api/v2/"
                displayLocation    = "https://www.powershellgallery.com/api/v2/"
                upstreamSourceType = "public"
                status             = "ok"
            }
            @{
                name               = "PyPI"
                protocol           = "pypi"
                location           = "https://pypi.org/"
                displayLocation    = "https://pypi.org/"
                upstreamSourceType = "public"
                status             = "ok"
            }
            @{
                name               = "Maven Central"
                protocol           = "Maven"
                location           = "https://repo.maven.apache.org/maven2/"
                displayLocation    = "https://repo.maven.apache.org/maven2/"
                upstreamSourceType = "public"
                status             = "ok"
            }
            @{
                name               = "Google Maven Repository"
                protocol           = "Maven"
                location           = "https://dl.google.com/android/maven2/"
                displayLocation    = "https://dl.google.com/android/maven2/"
                upstreamSourceType = "public"
                status             = "ok"
            }
            @{
                name               = "JitPack"
                protocol           = "Maven"
                location           = "https://jitpack.io/"
                displayLocation    = "https://jitpack.io/"
                upstreamSourceType = "public"
                status             = "ok"
            }
            @{
                name               = "Gradle Plugins"
                protocol           = "Maven"
                location           = "https://plugins.gradle.org/m2/"
                displayLocation    = "https://plugins.gradle.org/m2/"
                upstreamSourceType = "public"
                status             = "ok"
            }
            @{
                name               = "crates.io"
                protocol           = "Cargo"
                location           = "https://index.crates.io/"
                displayLocation    = "https://index.crates.io/"
                upstreamSourceType = "public"
                status             = "ok"
            }
        )
        $body.Add('upstreamSources', $upstreamSources)
    }

    $users = Get-ADOPSUser
    $buildService = $users.Where({ $_.displayName -eq "$Project build service ($Organization)" })
    if ($buildService.Count -eq 0) {
        Write-Verbose "Failed to find build service account. Not adding it as contributor."
    }
    else {
        $buildServiceDescriptorObject = invokeADOPSRestMethod -Uri "https://vssps.dev.azure.com/$Organization/_apis/Identities?identityIds=$($buildService.originId)" -Method Get
        $permissions = @(
            @{
                identityDescriptor = "$($buildServiceDescriptorObject.Descriptor.IdentityType);$($buildServiceDescriptorObject.Descriptor.Identifier)"
                role               = 'contributor'
                identityId         = $buildServiceDescriptorObject.Id
            }
        )
        $body.Add('permissions', $permissions)
    }

    $InvokeSplat = @{
        Uri    = $Uri
        Method = 'Post'
        Body   = $body | ConvertTo-Json -Compress
    }
    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSArtifactFeed

#region New-ADOPSAuditStream

function New-ADOPSAuditStream {
    [CmdletBinding(DefaultParameterSetName = 'AzureMonitorLogs')]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory, ParameterSetName = 'AzureMonitorLogs')]
        [ValidatePattern('^[a-fA-F0-9]{8}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{12}$', ErrorMessage = 'WorkspaceId should be in GUID format.')]
        [string]$WorkspaceId,

        [Parameter(Mandatory, ParameterSetName = 'AzureMonitorLogs')]
        [string]$SharedKey,

        [Parameter(Mandatory, ParameterSetName = 'Splunk')]
        [ValidatePattern('^(http|HTTP)[sS]?:\/\/', ErrorMessage = 'SplunkUrl must start with http:// or https://')]
        [string]$SplunkUrl,

        [Parameter(Mandatory, ParameterSetName = 'Splunk')]
        [ValidatePattern('^[a-fA-F0-9]{8}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{12}$', ErrorMessage = 'SplunkEventCollectorToken should be in GUID format.')]
        [string]$SplunkEventCollectorToken,

        [Parameter(Mandatory, ParameterSetName = 'AzureEventGrid')]
        [ValidatePattern('^(http|HTTP)[sS]?:\/\/', ErrorMessage = 'EventGridTopicHostname must start with http:// or https://')]
        [string]$EventGridTopicHostname,

        [Parameter(Mandatory, ParameterSetName = 'AzureEventGrid')]
        [ValidatePattern('^[A-Za-z0-9+\/]*={0,2}$', ErrorMessage = 'EventGridTopicAccessKey should be Base64 encoded')]
        [string]$EventGridTopicAccessKey
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Body = switch ($PSCmdlet.ParameterSetName) {
        'AzureMonitorLogs' { 
            [ordered]@{
                consumerType   = 'AzureMonitorLogs'
                consumerInputs = [Ordered]@{
                    WorkspaceId = $WorkspaceId
                    SharedKey   = $SharedKey
                }
            } | ConvertTo-Json -Compress
        }
        'Splunk' { 
            [ordered]@{
                consumerType   = 'Splunk'
                consumerInputs = [Ordered]@{
                    SplunkUrl                 = $SplunkUrl
                    SplunkEventCollectorToken = $SplunkEventCollectorToken
                }
            } | ConvertTo-Json -Compress
        }
        'AzureEventGrid' { 
            [ordered]@{
                consumerType   = 'AzureEventGrid'
                consumerInputs = [ordered]@{
                    EventGridTopicHostname  = $EventGridTopicHostname
                    EventGridTopicAccessKey = $EventGridTopicAccessKey
                }
            } | ConvertTo-Json -Compress
        }
    }
    $InvokeSplat = @{
        Uri    = "https://auditservice.dev.azure.com/$Organization/_apis/audit/streams?api-version=7.1-preview.1"
        Method = 'Post'
        Body   = $Body
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSAuditStream

#region New-ADOPSBuildPolicy

function New-ADOPSBuildPolicy {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Branch,

        [Parameter(Mandatory)]
        [int]$PipelineId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Displayname,

        [Parameter()]
        [string[]]$FilenamePatterns
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if (-Not ($Branch -match '^\w+/\w+/\w+$')) {
        $Branch = "refs/heads/$Branch"
    }
    $GitBranchRef = $Branch

    $settings = [ordered]@{
        scope                   = @(
            [ordered]@{
                repositoryId = $RepositoryId
                refName      = $GitBranchRef
                matchKind    = "exact"
            }
        )
        buildDefinitionId       = $PipelineId.ToString()
        queueOnSourceUpdateOnly = $false
        manualQueueOnly         = $false
        displayName             = $Displayname
        validDuration           = "0"
    }

    if ($FilenamePatterns.Count -gt 0) {
        $settings.Add('filenamePatterns', $FilenamePatterns)
    }

    $Body = [ordered]@{
        type       = [ordered]@{
            id = "0609b952-1397-4640-95ec-e00a01b2c241" 
        }
        isBlocking = $true
        isEnabled  = $true
        settings   = $settings
    } 
    
    $Body = $Body | ConvertTo-Json -Depth 10 -Compress
    
    $InvokeSplat = @{
        Uri    = "https://dev.azure.com/$Organization/$Project/_apis/policy/configurations?api-version=7.1-preview.1"
        Method = 'POST'
        Body   = $Body
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSBuildPolicy

#region New-ADOPSElasticpool

function New-ADOPSElasticPool {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PoolName,
        
        [Parameter(Mandatory)]
        $ElasticPoolObject,

        [Parameter()]
        [string]$ProjectId,

        [Parameter()]
        [switch]$AuthorizeAllPipelines,

        [Parameter()]
        [switch]$AutoProvisionProjectPools,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if ($PSBoundParameters.ContainsKey('ProjectId')) {
        $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/elasticpools?poolName=$PoolName`&authorizeAllPipelines=$AuthorizeAllPipelines`&autoProvisionProjectPools=$AutoProvisionProjectPools`&projectId=$ProjectId`&api-version=7.1-preview.1"
    }
    else {
        $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/elasticpools?poolName=$PoolName`&authorizeAllPipelines=$AuthorizeAllPipelines`&autoProvisionProjectPools=$AutoProvisionProjectPools`&api-version=7.1-preview.1"
    }

    if ($ElasticPoolObject.gettype().name -eq 'String') {
        $Body = $ElasticPoolObject
    }
    else {
        try {
            $Body = $ElasticPoolObject | ConvertTo-Json -Depth 100
        }
        catch {
            throw "Unable to convert the content of the ElasticPoolObject to json."
        }
    }
    
    $Method = 'POST'
    $ElasticPoolInfo = InvokeADOPSRestMethod -Uri $Uri -Method $Method -Body $Body
    Write-Output $ElasticPoolInfo
}
#endregion New-ADOPSElasticpool

#region New-ADOPSElasticPoolObject

function New-ADOPSElasticPoolObject {
    [SkipTest('HasOrganizationParameter')]
    [CmdletBinding()]
    param (
        # Service Endpoint Id
        [Parameter(Mandatory)]
        [guid]
        $ServiceEndpointId,

        # Service Endpoint Scope
        [Parameter(Mandatory)]
        [guid]
        $ServiceEndpointScope,

        # Azure Id
        [Parameter(Mandatory)]
        [string]
        $AzureId,

        # Operating System Type
        [Parameter()]
        [ValidateSet('linux', 'windows')]
        [string]
        $OsType = 'linux',

        # MaxCapacity
        [Parameter()]
        [int]
        $MaxCapacity = 1,

        # DesiredIdle
        [Parameter()]
        [int]
        $DesiredIdle = 0,

        # Recycle VM after each use
        [Parameter()]
        [boolean]
        $RecycleAfterEachUse = $false,

        # Desired Size of pool
        [Parameter()]
        [int]
        $DesiredSize = 0,

        # Agent Interactive UI
        [Parameter()]
        [boolean]
        $AgentInteractiveUI = $false,

        # Time before scaling down
        [Parameter()]
        [Alias('TimeToLiveMinues')]
        [int]
        $TimeToLiveMinutes = 15,

        # maxSavedNodeCount
        [Parameter()]
        [int]
        $MaxSavedNodeCount = 0,

        # Output Type
        [Parameter()]
        [ValidateSet('json', 'pscustomobject')]
        [string]
        $OutputType = 'pscustomobject'
    )

    if ($DesiredIdle -gt $MaxCapacity) {
        throw "The desired idle count cannot be larger than the max capacity."
    }

    $ElasticPoolObject = [PSCustomObject]@{
        serviceEndpointId    = $ServiceEndpointId
        serviceEndpointScope = $ServiceEndpointScope
        azureId              = $AzureId
        maxCapacity          = $MaxCapacity
        desiredIdle          = $DesiredIdle
        recycleAfterEachUse  = $RecycleAfterEachUse
        maxSavedNodeCount    = $MaxSavedNodeCount
        osType               = $OsType
        desiredSize          = $DesiredSize
        agentInteractiveUI   = $AgentInteractiveUI
        timeToLiveMinutes    = $TimeToLiveMinutes
    }
    
    if ($OutputType -eq 'json') {
        $ElasticPoolObject = $ElasticPoolObject | ConvertTo-Json -Depth 100
    }

    Write-Output $ElasticPoolObject
}
#endregion New-ADOPSElasticPoolObject

#region New-ADOPSEnvironment

function New-ADOPSEnvironment {
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [string]$AdminGroup,
        
        [Parameter()]
        [switch]$SkipAdmin
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$organization/$project/_apis/distributedtask/environments?api-version=7.1-preview.1"

    $Body = [Ordered]@{
        name        = $Name
        description = $Description
    } | ConvertTo-Json -Compress

    $InvokeSplat = @{
        Uri    = $Uri
        Method = 'Post'
        Body   = $Body
    }

    Write-Verbose "Setting up environment"
    $Environment = InvokeADOPSRestMethod @InvokeSplat

    if ($PSBoundParameters.ContainsKey('SkipAdmin')) {
        Write-Verbose 'Skipped admin group'
    }
    else {
        $secUri = "https://dev.azure.com/$organization/_apis/securityroles/scopes/distributedtask.environmentreferencerole/roleassignments/resources/$($Environment.project.id)_$($Environment.id)?api-version=7.1-preview.1"

        if ([string]::IsNullOrEmpty($AdminGroup)) {
            $AdmGroupPN = "[$project]\Project Administrators"
        } 
        else {
            $AdmGroupPN = $AdminGroup
        }
        $ProjAdm = (Get-ADOPSGroup | Where-Object { $_.principalName -eq $AdmGroupPN }).originId

        $SecInvokeSplat = @{
            Uri    = $secUri
            Method = 'Put'
            Body   = "[{`"userId`":`"$ProjAdm`",`"roleName`":`"Administrator`"}]"
        }

        try {
            $SecResult = InvokeADOPSRestMethod @SecInvokeSplat
        }
        catch {
            Write-Error 'Failed to update environment security. The environment may still have been created.'
        }
    }

    Write-Output $Environment
}
#endregion New-ADOPSEnvironment

#region New-ADOPSGitBranch

function New-ADOPSGitBranch {
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]{8}\-[a-z0-9]{4}\-[a-z0-9]{4}\-[a-z0-9]{4}\-[a-z0-9]{12}$', ErrorMessage = 'RepositoryId must be in GUID format (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)')]
        [string]$RepositoryId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,

        [Parameter(Mandatory)]
        [ValidateLength(40, 40)]
        [string]$CommitId
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Body = @(
        [ordered]@{
            name        = "refs/heads/$BranchName"
            oldObjectId = '0000000000000000000000000000000000000000'
            newObjectId = $CommitId
        }
    )
    $Body = ConvertTo-Json -InputObject $Body -Compress

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/refs?api-version=7.1-preview.1"
    $InvokeSplat = @{
        Uri    = $Uri
        Method = 'Post'
        Body   = $Body
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSGitBranch

#region New-ADOPSGitFile

function New-ADOPSGitFile {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,
        
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [string]$Repository,
        
        [Parameter(Mandatory)]
        [string]$File,
        
        [Parameter()]
        [string]$FileName,
        
        [Parameter()]
        [string]$Path,
        
        [Parameter()]
        [string]$CommitMessage = 'File added using the ADOPS PowerShell module'
    )

    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }
    
    if ([string]::IsNullOrEmpty($Path)) {
        $Path = '/'
    }

    if ([string]::IsNullOrEmpty($FileName)) {
        $FileName = (Get-Item -Path $File).Name
    }

    $newFilePath = "/${Path}/$FileName" -replace '/{2,}', '/' # Make sure there are never two or more slashes in a row.

    $repoDetails = Get-ADOPSRepository -Project $Project -Repository $Repository

    $refIduri = "$($repoDetails.url)/refs?filter=$($repoDetails.defaultBranch -replace '^refs/','')&includeStatuses=true&latestStatusesOnly=true&api-version=7.2-preview.2"
    $refId = InvokeADOPSRestMethod -Uri $refIduri -Method Get | Select-Object -ExpandProperty value
    
    $body = [ordered]@{
        refUpdates = @(
            [ordered]@{
                name        = $repoDetails.defaultBranch
                oldObjectId = $refId.objectId
            }
        )
        commits    = @(
            [ordered]@{
                comment = $CommitMessage
                changes = @(
                    [ordered]@{
                        changeType = "add"
                        item       = [ordered]@{
                            path = $newFilePath
                        }
                        newContent = [ordered]@{
                            content     = $(Get-Content $File -Raw)
                            contentType = "rawtext"
                        }
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 100 -Compress

    $Uri = "$($repoDetails.url)/pushes?api-version=7.2-preview.3"
    $InvokeSplat = @{
        Method = 'Post'
        Uri    = $Uri
        Body   = $Body
    }
    
    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSGitFile

#region New-ADOPSGroupEntitlement

function New-ADOPSGroupEntitlement {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupOriginId,

        [Parameter(Mandatory)]
        [ValidateSet('Express', 'Advanced', 'Stakeholder', 'Professional', 'EarlyAdopter')]
        [string]$AccountLicenseType,

        [Parameter(Mandatory)]
        [ValidateSet('projectReader', 'projectContributor', 'projectAdministrator', 'projectStakeholder')]
        [string]$ProjectGroupType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter()]
        [switch]$Wait
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    # Group entitlements endpoint
    $URI = "https://vsaex.dev.azure.com/$Organization/_apis/GroupEntitlements?api-version=7.1"

    # Initialize the request body
    $Body = @{
        extensionRules      = @(
            @{
                id = 'ms.feed'
            }
        )
        group               = @{
            origin      = 'aad'
            originId    = $GroupOriginId
            subjectKind = 'group'
        }
        licenseRule         = @{
            licensingSource    = 'account'
            accountLicenseType = $AccountLicenseType
        }
        projectEntitlements = @(
            @{
                group      = @{
                    groupType = $ProjectGroupType
                }
                projectRef = @{
                    id = $ProjectId
                }
            }
        )
    }

    $InvokeSplat = @{
        Method = 'Post'
        Uri    = $URI
        Body   = ($Body | ConvertTo-Json -Compress -Depth 10)
    }

    $Out = InvokeADOPSRestMethod @InvokeSplat

    if ($PSBoundParameters.ContainsKey('Wait')) {
        while ($Out.operationResult.status -eq 'inProgress') {
            Start-Sleep -Seconds 1
            $Out = Invoke-ADOPSRestMethod -Uri $Out.operationResult.statusUrl -Method Get
        }
    }

    $Out
}
#endregion New-ADOPSGroupEntitlement

#region New-ADOPSMergePolicy

function New-ADOPSMergePolicy {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Branch,

        [Parameter()]
        [Switch]$AllowNoFastForward,

        [Parameter()]
        [Switch]$AllowSquash,

        [Parameter()]
        [Switch]$AllowRebase,

        [Parameter()]
        [Switch]$AllowRebaseMerge
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    if (-Not ($Branch -match '^\w+/\w+/\w+$')) {
        $Branch = "refs/heads/$Branch"
    }
    $GitBranchRef = $Branch

    $settings = [ordered]@{
        scope              = @(
            [ordered]@{
                repositoryId = $RepositoryId
                refName      = $GitBranchRef
                matchKind    = "exact"
            }
        )
        allowNoFastForward = $AllowNoFastForward.IsPresent
        allowSquash        = $AllowSquash.IsPresent
        allowRebase        = $AllowRebase.IsPresent
        allowRebaseMerge   = $AllowRebaseMerge.IsPresent
    }


    $Body = [ordered]@{
        type       = [ordered]@{
            id = "fa4e907d-c16b-4a4c-9dfa-4916e5d171ab" 
        }
        isBlocking = $true
        isEnabled  = $true
        settings   = $settings
    } 
    
    $Body = $Body | ConvertTo-Json -Depth 10 -Compress
    
    $InvokeSplat = @{
        Uri    = "https://dev.azure.com/$Organization/$Project/_apis/policy/configurations?api-version=7.1-preview.1"
        Method = 'POST'
        Body   = $Body
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSMergePolicy

#region New-ADOPSPipeline

function New-ADOPSPipeline {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory)]
        [ValidateScript( { 
                $_ -like '*.yaml' -or
                $_ -like '*.yml'
            },
            ErrorMessage = "Path must be to a yaml file in your repository like: folder/file.yaml or folder/file.yml")] 
        [string]$YamlPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Repository,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$FolderPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/pipelines?api-version=7.1-preview.1"

    try {
        $RepositoryID = (Get-ADOPSRepository -Organization $Organization -Project $Project -Repository $Repository -ErrorAction Stop).id
    }
    catch {
        throw "The specified Repository $Repository was not found."
    }

    if ($null -eq $RepositoryID) {
        throw "The specified Repository $Repository was not found."
    }

    $Body = [ordered]@{
        "name"          = $Name
        "folder"        = "\$FolderPath"
        "configuration" = [ordered]@{
            "type"       = "yaml"
            "path"       = $YamlPath
            "repository" = [ordered]@{
                "id"   = $RepositoryID
                "type" = "azureReposGit"
            }
        }
    }
    $Body = $Body | ConvertTo-Json -Compress

    $InvokeSplat = @{
        Method = 'Post'
        Uri    = $URI
        Body   = $Body 
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSPipeline

#region New-ADOPSProject

function New-ADOPSProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('Project')]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Description,
        
        [Parameter(Mandatory)]
        [ValidateSet('Private', 'Public')]
        [string]$Visibility,
        
        [Parameter()]
        [ValidateSet('Git', 'Tfvc')]
        [string]$SourceControlType = 'Git',
        
        # The process type for the project, such as Basic, Agile, Scrum or CMMI
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProcessTypeName,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,
        
        [Parameter()]
        [switch]$Wait
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    # Get organization process templates
    $URI = "https://dev.azure.com/$Organization/_apis/process/processes?api-version=7.1-preview.1"

    $InvokeSplat = @{
        Method = 'Get'
        Uri    = $URI
    }

    $ProcessTemplates = (InvokeADOPSRestMethod @InvokeSplat).value

    if ([string]::IsNullOrWhiteSpace($ProcessTypeName)) {
        $ProcessTemplateTypeId = $ProcessTemplates | Where-Object isDefault -eq $true | Select-Object -ExpandProperty id
    }
    else {
        $ProcessTemplateTypeId = $ProcessTemplates | Where-Object name -eq $ProcessTypeName | Select-Object -ExpandProperty id
        if ([string]::IsNullOrWhiteSpace($ProcessTemplateTypeId)) {
            throw "The specified ProcessTypeName was not found amongst options: $($ProcessTemplates.name -join ', ')!"
        }
    }

    # Create project endpoint
    $URI = "https://dev.azure.com/$Organization/_apis/projects?api-version=7.1-preview.4"

    $Body = [ordered]@{
        'name'         = $Name
        'visibility'   = $Visibility
        'capabilities' = [ordered]@{
            'versioncontrol'  = [ordered]@{
                'sourceControlType' = $SourceControlType
            }
            'processTemplate' = [ordered]@{
                'templateTypeId' = $ProcessTemplateTypeId
            }
        }
    }
    if (-not [string]::IsNullOrEmpty($Description)) {
        $Body.Add('description', $Description)
    }
    $Body = $Body | ConvertTo-Json -Compress
    
    $InvokeSplat = @{
        Method = 'Post'
        Uri    = $URI
        Body   = $Body
    }

    $Out = InvokeADOPSRestMethod @InvokeSplat

    if ($PSBoundParameters.ContainsKey('Wait')) {
        $projectCreated = $Out.status
        while ($projectCreated -ne 'succeeded') {
            $projectCreated = (Invoke-ADOPSRestMethod -Uri $Out.url -Method Get).status
            Start-Sleep -Seconds 1
        }
        $Out = Get-ADOPSProject -Project $Name 
    }

    $Out
}
#endregion New-ADOPSProject

#region New-ADOPSRepository

function New-ADOPSRepository {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $ProjectID = (Get-ADOPSProject -Name $Project -Organization $Organization).id

    $URI = "https://dev.azure.com/$Organization/_apis/git/repositories?api-version=7.1-preview.1"
    $Body = "{""name"":""$Name"",""project"":{""id"":""$ProjectID""}}"

    $InvokeSplat = @{
        Uri    = $URI
        Method = 'Post'
        Body   = $Body
    }
    
    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSRepository

#region New-ADOPSServiceConnection

function New-ADOPSServiceConnection {
    [cmdletbinding(DefaultParameterSetName = 'ServicePrincipal')]
    param(
        [Parameter()]
        [string]$Organization,
        
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$SubscriptionName,

        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter()]
        [string]$ConnectionName,

        [Parameter()]
        [string]$Description,
      
        [Parameter(Mandatory, ParameterSetName = 'ServicePrincipal')]
        [Parameter(Mandatory, ParameterSetName = 'ManagedServiceIdentity')]
        [pscredential]$ServicePrincipal,

        [Parameter(Mandatory, ParameterSetName = 'ManagedServiceIdentity')]
        [switch]$ManagedIdentity,

        [Parameter(Mandatory, ParameterSetName = 'WorkloadIdentityFederation')]
        [switch]$WorkloadIdentityFederation,

        [Parameter(ParameterSetName = 'WorkloadIdentityFederation')]
        [string]$AzureScope,

        [Parameter(ParameterSetName = 'WorkloadIdentityFederation')]
        [ValidateSet('Manual', 'Automatic')]
        [string]
        $CreationMode = 'Automatic'
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    # Get ProjectId
    $ProjectInfo = Get-ADOPSProject -Organization $Organization -Project $Project

    # Set connection name if not set by parameter
    if (-not $ConnectionName) {
        $ConnectionName = $SubscriptionName -replace ' '
    }
    
    switch ($PSCmdlet.ParameterSetName) {
        
        'ServicePrincipal' {
            $authorization = [ordered]@{
                parameters = [ordered]@{
                    tenantid            = $TenantId
                    serviceprincipalid  = $ServicePrincipal.UserName
                    authenticationType  = 'spnKey'
                    serviceprincipalkey = $ServicePrincipal.GetNetworkCredential().Password
                }
                scheme     = 'ServicePrincipal'
            }
    
            $data = [ordered]@{
                subscriptionId   = $SubscriptionId
                subscriptionName = $SubscriptionName
                environment      = 'AzureCloud'
                scopeLevel       = 'Subscription'
                creationMode     = 'Manual'
            }
        }

        'ManagedServiceIdentity' {
            $authorization = [ordered]@{
                parameters = [ordered]@{
                    tenantid            = $TenantId
                    serviceprincipalid  = $ServicePrincipal.UserName
                    serviceprincipalkey = $ServicePrincipal.GetNetworkCredential().Password
                }
                scheme     = 'ManagedServiceIdentity'
            }
    
            $data = [ordered]@{
                subscriptionId   = $SubscriptionId
                subscriptionName = $SubscriptionName
                environment      = 'AzureCloud'
                scopeLevel       = 'Subscription'
            }
        }

        'WorkloadIdentityFederation' {
            if ($PSBoundParameters.ContainsKey('AzureScope')) {
                $AuthParams = [ordered]@{
                    tenantid = $TenantId
                    scope    = $AzureScope
                }
            }
            else {
                $AuthParams = [ordered]@{
                    tenantid = $TenantId
                }
            }

            $authorization = [ordered]@{
                parameters = $AuthParams
                scheme     = 'WorkloadIdentityFederation'
            }
    
            $data = [ordered]@{
                subscriptionId   = $SubscriptionId
                subscriptionName = $SubscriptionName
                environment      = 'AzureCloud'
                scopeLevel       = 'Subscription'
                creationMode     = $CreationMode
                isDraft          = ($CreationMode = 'Manual') ? $True : $False
            }
        }
    }

    # Create body for the API call
    $Body = [ordered]@{
        data                             = $data
        name                             = $ConnectionName
        description                      = $Description
        type                             = 'AzureRM'
        url                              = 'https://management.azure.com/'
        authorization                    = $authorization
        isShared                         = $false
        isReady                          = $true
        serviceEndpointProjectReferences = @(
            [ordered]@{
                projectReference = [ordered]@{
                    id   = $ProjectInfo.Id
                    name = $Project
                }
                name             = $ConnectionName
            }
        )
    } | ConvertTo-Json -Depth 10

    # Run function
    $URI = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints?api-version=7.2-preview.4"
    $InvokeSplat = @{
        Uri    = $URI
        Method = 'POST'
        Body   = $Body
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSServiceConnection

#region New-ADOPSUserStory

function New-ADOPSUserStory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string]$Tags,

        [Parameter()]
        [string]$Priority,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $URI = "https://dev.azure.com/$Organization/$ProjectName/_apis/wit/workitems/`$User Story?api-version=7.1-preview.3"
    $Method = 'POST'

    $desc = $Description.Replace('"', "'")
    $Body = "[
      {
        `"op`": `"add`",
        `"path`": `"/fields/System.Title`",
        `"value`": `"$($Title)`"
      },
      {
        `"op`": `"add`",
        `"path`": `"/fields/System.Description`",
        `"value`": `"$($desc)`"
      },
      {
        `"op`": `"add`",
        `"path`": `"/fields/System.Tags`",
        `"value`": `"$($Tags)`"
      },
      {
        `"op`": `"add`",
        `"path`": `"/fields/Microsoft.VSTS.Common.Priority`",
        `"value`": `"$($Priority)`"
      },	 
    ]"
    
    $ContentType = 'application/json-patch+json'  
  
    $InvokeSplat = @{
        Uri         = $URI
        ContentType = $ContentType
        Method      = $Method
        Body        = $Body
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSUserStory

#region New-ADOPSVariableGroup

function New-ADOPSVariableGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$VariableGroupName,

        [Parameter(Mandatory, ParameterSetName = 'VariableSingle')]
        [string]$VariableName,

        [Parameter(Mandatory, ParameterSetName = 'VariableSingle')]
        [string]$VariableValue,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(ParameterSetName = 'VariableSingle')]
        [switch]$IsSecret,

        [Parameter(Mandatory, ParameterSetName = 'VariableHashtable')]
        [ValidateScript(
            {
                $_ | ForEach-Object { $_.Keys -Contains 'Name' -and $_.Keys -Contains 'IsSecret' -and $_.Keys -Contains 'Value' -and $_.Keys.count -eq 3 }
            },
            ErrorMessage = 'The hashtable must contain the following keys: Name, IsSecret, Value')]
        [hashtable[]]$VariableHashtable,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $ProjectInfo = Get-ADOPSProject -Organization $Organization -Project $Project

    $URI = "https://dev.azure.com/${Organization}/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
    $Method = 'POST'

    if ($VariableName) {
        $Body = @{
            Name                           = $VariableGroupName
            Description                    = $Description
            Type                           = 'Vsts'
            variableGroupProjectReferences = @(@{
                    Name             = $VariableGroupName
                    Description      = $Description
                    projectReference = @{
                        Id = $ProjectInfo.Id
                    }
                })
            variables                      = @{
                $VariableName = @{
                    isSecret = $IsSecret.IsPresent
                    value    = $VariableValue
                }
            }
        } | ConvertTo-Json -Depth 10
    }
    else {

        $Variables = @{}
        foreach ($Hashtable in $VariableHashtable) {
            $Variables.Add(
                $Hashtable.Name, @{
                    isSecret = $Hashtable.IsSecret
                    value    = $Hashtable.Value
                }
            )
        }

        $Body = @{
            Name                           = $VariableGroupName
            Description                    = $Description
            Type                           = 'Vsts'
            variableGroupProjectReferences = @(@{
                    Name             = $VariableGroupName
                    Description      = $Description
                    projectReference = @{
                        Id = $($ProjectInfo.Id)
                    }
                })
            variables                      = $Variables
        } | ConvertTo-Json -Depth 10
    }

    InvokeADOPSRestMethod -Uri $Uri -Method $Method -Body $Body
}
#endregion New-ADOPSVariableGroup

#region New-ADOPSWiki

function New-ADOPSWiki {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$WikiName,
        
        [Parameter(Mandatory)]
        [string]$WikiRepository,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter()]
        [string]$WikiRepositoryPath = '/',
        
        [Parameter()]
        [string]$GitBranch = 'main',

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    try {
        $ProjectId = (Get-ADOPSProject -Project $Project).id
    }
    catch {
        throw "The specified Project $Project was not found."
    }
    if ($null -eq $ProjectId) {
        throw "The specified Project $Project was not found."
    }

    try {
        $RepositoryId = (Get-ADOPSRepository -Project $Project -Repository $WikiRepository).id
    }
    catch {
        throw "The specified Repository $WikiRepository was not found."
    }

    if ($null -eq $RepositoryID) {
        throw "The specified Repository $WikiRepository was not found."
    }

    $URI = "https://dev.azure.com/$Organization/_apis/wiki/wikis?api-version=7.1-preview.2"
    
    $Method = 'Post'
    $Body = [ordered]@{
        'type'         = 'codeWiki'
        'name'         = $WikiName
        'projectId'    = $ProjectId
        'repositoryId' = $RepositoryId
        'mappedPath'   = $WikiRepositoryPath
        'version'      = @{'version' = $GitBranch }
    } 

    $InvokeSplat = @{
        Uri    = $URI
        Method = $Method
        Body   = $Body | ConvertTo-Json -Compress
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion New-ADOPSWiki

#region Remove-ADOPSRepository

function Remove-ADOPSRepository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryID,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryID`?api-version=7.1-preview.1"
    
    $result = InvokeADOPSRestMethod -Uri $Uri -Method Delete

    if ($result.psobject.properties.name -contains 'value') {
        Write-Output -InputObject $result.value
    }
    else {
        Write-Output -InputObject $result
    }
}
#endregion Remove-ADOPSRepository

#region Remove-ADOPSVariableGroup

function Remove-ADOPSVariableGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$VariableGroupName,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
    $VariableGroups = (InvokeADOPSRestMethod -Uri $Uri -Method 'Get').value

    $GroupToRemove = $VariableGroups | Where-Object name -eq $VariableGroupName
    if ($null -eq $GroupToRemove) {
        throw "Could not find group $VariableGroupName! Groups found: $($VariableGroups.name -join ', ')."
    }
    
    $ProjectId = (Get-ADOPSProject -Organization $Organization -Project $Project).id

    $URI = "https://dev.azure.com/$Organization/_apis/distributedtask/variablegroups/$($GroupToRemove.id)?projectIds=$ProjectId&api-version=7.1-preview.2"
    $null = InvokeADOPSRestMethod -Uri $Uri -Method 'Delete'
}
#endregion Remove-ADOPSVariableGroup

#region Revoke-ADOPSPipelinePermission

function Revoke-ADOPSPipelinePermission {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [string]$Project,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [switch]$AllPipelines,

        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [int]$PipelineId,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [ResourceType]$ResourceType,

        [Parameter(Mandatory, ParameterSetName = 'AllPipelines')]
        [Parameter(Mandatory, ParameterSetName = 'SinglePipeline')]
        [string]$ResourceId,

        [Parameter(ParameterSetName = 'AllPipelines')]
        [Parameter(ParameterSetName = 'SinglePipeline')]
        [string]$Organization
    )

    SetADOPSPipelinePermission @PSBoundParameters -Authorized $false
}
#endregion Revoke-ADOPSPipelinePermission

#region Save-ADOPSPipelineTask

function Save-ADOPSPipelineTask {
    [CmdletBinding(DefaultParameterSetName = 'InputData')]
    param (
        [Parameter(ParameterSetName = 'InputData')]
        [Parameter(ParameterSetName = 'InputObject')]
        [string]$Organization,

        [Parameter(ParameterSetName = 'InputData')]
        [Parameter(ParameterSetName = 'InputObject')]
        [string]$Path = '.',

        [Parameter(Mandatory, ParameterSetName = 'InputData')]
        [string]$TaskId,

        [Parameter(Mandatory, ParameterSetName = 'InputData')]
        [version]$TaskVersion,

        [Parameter(ParameterSetName = 'InputData')]
        [string]$FileName,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline, Position = 0)]
        [psobject[]]$InputObject
    )
    begin {
        # If user didn't specify org, get it from saved context
        if ([string]::IsNullOrEmpty($Organization)) {
            $Organization = GetADOPSDefaultOrganization
        }
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'InputData' {
                if ([string]::IsNullOrEmpty($FileName)) {
                    $FileName = "$TaskId.$($TaskVersion.ToString(3)).zip"
                }
                if (-Not $FileName -match '.zip$' ) {
                    $FileName = "$FileName.zip"
                }

                [array]$FilesToDownload = @{
                    TaskId            = $TaskId
                    TaskVersionString = $TaskVersion.ToString(3)
                    OutputFile        = Join-Path -Path $Path -ChildPath $FileName
                }
            }
            'InputObject' {
                [array]$FilesToDownload = foreach ($o in $InputObject) {
                    @{
                        TaskId            = $o.id
                        TaskVersionString = "$($o.version.major).$($o.version.minor).$($o.version.patch)"
                        OutputFile        = Join-Path -Path $Path -ChildPath "$($o.name)-$($o.id)-$($o.version.major).$($o.version.minor).$($o.version.patch).zip"
                    }
                }
            }
        }

        foreach ($File in $FilesToDownload) {
            $Url = "https://dev.azure.com/$Organization/_apis/distributedtask/tasks/$($File.TaskId)/$($File.TaskversionString)"
            InvokeADOPSRestMethod -Uri $Url -Method Get -OutFile $File.OutputFile
        }
    }
    end {}
}
#endregion Save-ADOPSPipelineTask

#region Set-ADOPSArtifactFeed

function Set-ADOPSArtifactFeed {
    [CmdletBinding()]
    param (   
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [Alias('Name')]
        [string]$FeedId,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [Alias('IncludeUpstream')]
        [bool]$UpstreamEnabled
    )
 
    if (
        -not ($PSBoundParameters.ContainsKey('Description')) -and
        -not ($PSBoundParameters.ContainsKey('UpstreamEnabled'))
    ) {
        Write-Verbose 'Nothing to do. Exiting early'
    }
    else {
        # If user didn't specify org, get it from saved context
        if ([string]::IsNullOrEmpty($Organization)) {
            $Organization = GetADOPSDefaultOrganization
        }
        
        $Uri = "https://feeds.dev.azure.com/${Organization}/${Project}/_apis/packaging/feeds/${FeedId}?api-version=7.2-preview.1"
        $Method = 'Patch'

        $Body = [ordered]@{}
        if ($PSBoundParameters.ContainsKey('Description')) {
            $Body['description'] = $Description
        }
        if ($PSBoundParameters.ContainsKey('UpstreamEnabled')) {
            $Body['upstreamEnabled'] = $UpstreamEnabled
            if ($UpstreamEnabled -eq $true) {                
                $upstreamSources = @(
                    @{
                        name               = "npmjs"
                        protocol           = "npm"
                        location           = "https://registry.npmjs.org/"
                        displayLocation    = "https://registry.npmjs.org/"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                    @{
                        name               = "NuGet Gallery"
                        protocol           = "nuget"
                        location           = "https://api.nuget.org/v3/index.json"
                        displayLocation    = "https://api.nuget.org/v3/index.json"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                    @{
                        name               = "PowerShell Gallery"
                        protocol           = "nuget"
                        location           = "https://www.powershellgallery.com/api/v2/"
                        displayLocation    = "https://www.powershellgallery.com/api/v2/"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                    @{
                        name               = "PyPI"
                        protocol           = "pypi"
                        location           = "https://pypi.org/"
                        displayLocation    = "https://pypi.org/"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                    @{
                        name               = "Maven Central"
                        protocol           = "Maven"
                        location           = "https://repo.maven.apache.org/maven2/"
                        displayLocation    = "https://repo.maven.apache.org/maven2/"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                    @{
                        name               = "Google Maven Repository"
                        protocol           = "Maven"
                        location           = "https://dl.google.com/android/maven2/"
                        displayLocation    = "https://dl.google.com/android/maven2/"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                    @{
                        name               = "JitPack"
                        protocol           = "Maven"
                        location           = "https://jitpack.io/"
                        displayLocation    = "https://jitpack.io/"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                    @{
                        name               = "Gradle Plugins"
                        protocol           = "Maven"
                        location           = "https://plugins.gradle.org/m2/"
                        displayLocation    = "https://plugins.gradle.org/m2/"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                    @{
                        name               = "crates.io"
                        protocol           = "Cargo"
                        location           = "https://index.crates.io/"
                        displayLocation    = "https://index.crates.io/"
                        upstreamSourceType = "public"
                        status             = "ok"
                    }
                )
                $body.Add('upstreamSources', $upstreamSources)
            }
        }

        $Body = $Body | ConvertTo-Json -Compress

        $InvokeSplat = @{
            Uri    = $Uri
            Method = $Method
            Body   = $Body
        }

        InvokeADOPSRestMethod @InvokeSplat
    }
}
#endregion Set-ADOPSArtifactFeed

#region Set-ADOPSBuildDefinition

function Set-ADOPSBuildDefinition {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [string]$Organization,
        
        [Parameter(Mandatory)]
        [Alias('Definition')]
        [Object]$DefinitionObject
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $project = $DefinitionObject.project.id
    $id = $DefinitionObject.id

    $Uri = "https://dev.azure.com/${Organization}/${project}/_apis/build/definitions/${id}?api-version=7.2-preview.7"
    $Method = 'Put'

    if (-Not ($DefinitionObject -is [string])) {
        $DefinitionObject = $DefinitionObject | ConvertTo-Json -Compress -Depth 100
    }

    $InvokeSplat = @{
        Uri    = $Uri
        Method = $Method
        Body   = $DefinitionObject
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion Set-ADOPSBuildDefinition

#region Set-ADOPSElasticPool

function Set-ADOPSElasticPool {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$PoolId,
        
        [Parameter(Mandatory)]
        $ElasticPoolObject,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/_apis/distributedtask/elasticpools/$PoolId`?api-version=7.1-preview.1"

    if ($ElasticPoolObject.GetType().Name -eq 'String') {
        $Body = $ElasticPoolObject
    }
    else {
        try {
            $Body = $ElasticPoolObject | ConvertTo-Json -Depth 100
        }
        catch {
            throw 'Unable to convert the content of the ElasticPoolObject to json.'
        }
    }
    
    $Method = 'PATCH'
    $ElasticPoolInfo = InvokeADOPSRestMethod -Uri $Uri -Method $Method -Body $Body
    Write-Output $ElasticPoolInfo
}
#endregion Set-ADOPSElasticPool

#region Set-ADOPSGitPermission

function Set-ADOPSGitPermission {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,
        
        [Parameter(Mandatory)]
        [Alias('ProjectId')]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [Alias('RepositoryId')]
        [string]$Repository,
        
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z]{3,5}\.[a-zA-Z0-9]{40,}$', ErrorMessage = 'Descriptor must be in the descriptor format')]
        [string]$Descriptor,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [AccessLevels[]]$Allow,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [AccessLevels[]]$Deny
    )
    
    # Allow input of names instead of IDs
    if ($Project -notmatch '^[a-z0-9]{8}\-[a-z0-9]{4}\-[a-z0-9]{4}\-[a-z0-9]{4}\-[a-z0-9]{12}$') {
        $Project = Get-ADOPSProject -Name $Project | Select-Object -ExpandProperty id
        if ($null -eq $Project) {
            throw "No project named $Project found."
        }
    }
    if ($Repository -notmatch '^[a-z0-9]{8}\-[a-z0-9]{4}\-[a-z0-9]{4}\-[a-z0-9]{4}\-[a-z0-9]{12}$') {
        $Repository = Get-ADOPSRepository -Repository $Repository -Project $Project
        if ($null -eq $Repository) {
            throw "No repository named $Repository in project $Project found."
        }
    }


    if (-not $Allow -and -not $Deny) {
        Write-Verbose 'No allow or deny rules set'
    }
    else {
        if ($null -eq $Allow) {
            $allowRules = 0
        }
        else {
            $allowRules = ([accesslevels]$Allow).value__
        }
        if ($null -eq $Deny) {
            $denyRules = 0
        }
        else {
            $denyRules = ([accesslevels]$Deny).value__
        }
    
        # If user didn't specify org, get it from saved context
        if ([string]::IsNullOrEmpty($Organization)) {
            $Organization = GetADOPSDefaultOrganization
        }
        
        $SubjectDescriptor = (InvokeADOPSRestMethod -Uri "https://vssps.dev.azure.com/$Organization/_apis/identities?subjectDescriptors=$Descriptor&queryMembership=None&api-version=7.1-preview.1" -Method Get).value.descriptor

        $Body = [ordered]@{
            token                = "repov2/$Project/$Repository"
            merge                = $true
            accessControlEntries = @(
                [ordered]@{
                    allow      = $allowRules
                    deny       = $denyRules
                    descriptor = $SubjectDescriptor
                }
            )
        } | ConvertTo-Json -Compress -Depth 10
        
        $Uri = "https://dev.azure.com/$Organization/_apis/accesscontrolentries/2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87?api-version=7.1-preview.1"
        
        $InvokeSplat = @{
            Uri    = $Uri 
            Method = 'Post' 
            Body   = $Body
        }
        
        InvokeADOPSRestMethod @InvokeSplat
    }
}
#endregion Set-ADOPSGitPermission

#region Set-ADOPSPipelineRetentionSettings

function Set-ADOPSPipelineRetentionSettings {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $Values
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/build/retention?api-version=7.1-preview.1"

    $Body = ConvertRetentionSettingsToPatchBody -Values $Values | ConvertTo-Json
    Write-Debug $Body
    
    $Response = InvokeADOPSRestMethod -Uri $Uri -Method Patch -Body $Body
    Write-Debug $Response

    $Settings = ConvertRetentionSettingsGetToPatch -Response $Response
    
    Write-Output $Settings
}
#endregion Set-ADOPSPipelineRetentionSettings

#region Set-ADOPSPipelineSettings

function Set-ADOPSPipelineSettings {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory)]
        $Values
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/build/generalsettings?api-version=7.1-preview.1"

    $Body = $Values | ConvertTo-Json -Compress
    $Settings = InvokeADOPSRestMethod -Uri $Uri -Method 'PATCH' -Body $Body

    Write-Output $Settings
}
#endregion Set-ADOPSPipelineSettings

#region Set-ADOPSProject

function Set-ADOPSProject {
    [CmdletBinding(DefaultParameterSetName = 'ProjectName')]
    param (    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,
        
        [Parameter(Mandatory, ParameterSetName = 'ProjectId')]
        [ValidateScript({
                [guid]::Parse($_)
            }, ErrorMessage = 'ProjectID format is wrong.')]
        [string]$ProjectId,
        
        [Parameter(Mandatory, ParameterSetName = 'ProjectName')]
        [ValidateNotNullOrEmpty()]
        [Alias('Project', 'Name')]
        [string]$ProjectName,

        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [ValidateSet('Private', 'Public')]
        [string]$Visibility,
        
        [Parameter()]
        [switch]$Wait
    )

    if (-Not ($PSBoundParameters.ContainsKey('Description')) -and -Not ($PSBoundParameters.ContainsKey('Visibility'))) {
        Write-Verbose 'Nothing to update. Exiting.'
    }
    else {
        # If user didn't specify org, get it from saved context
        if ([string]::IsNullOrEmpty($Organization)) {
            $Organization = GetADOPSDefaultOrganization
        }

        if ($PSCmdlet.ParameterSetName -eq 'ProjectName') {
            $ProjectId = Get-ADOPSProject -Name $ProjectName | Select-Object -ExpandProperty id
        }

        $uri = "https://dev.azure.com/${Organization}/_apis/projects/${ProjectId}?api-version=7.2-preview.4"

        
        $body = [ordered]@{}
        
        if ($PSBoundParameters.ContainsKey('Description')) {
            $body.Add('description', $Description)
        }

        if (-not [string]::IsNullOrEmpty($Visibility)) {
            $body.Add('visibility', $Visibility.ToLower())
        }
            
        $body = $body | ConvertTo-Json -Compress

        $InvokeSplat = [ordered]@{
            'Uri'    = $uri
            'Method' = 'Patch'
            'Body'   = $body
        }

        $res = InvokeADOPSRestMethod @InvokeSplat

        if ($PSBoundParameters.ContainsKey('Wait')) {
            $i = 0
            while (($res.status -notin @('cancelled', 'failed', 'succeeded')) -and $i -le 20) {
                $res = InvokeADOPSRestMethod -Uri $res.url -Method Get
                $i++
                Start-Sleep -Seconds 1
            }
            if ($i -ge 20) {
                Write-Verbose 'Status still not complete, failed, or canceled. Please verify project update.'
            }
        }

        $res
    }
}
#endregion Set-ADOPSProject

#region Set-ADOPSRepository

function Set-ADOPSRepository {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultBranch,

        [Parameter()]
        [bool]$IsDisabled,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NewName
    )

    if ( ([string]::IsNullOrEmpty($DefaultBranch)) -and ([string]::IsNullOrEmpty($NewName)) -and (-Not $PSBoundParameters.ContainsKey('IsDisabled')) ) {
        # Nothing to do, exit early
    }
    else {
        # If user didn't specify org, get it from saved context
        if ([string]::IsNullOrEmpty($Organization)) {
            $Organization = GetADOPSDefaultOrganization
        }
        
        $URI = "https://dev.azure.com/${Organization}/${Project}/_apis/git/repositories/${RepositoryId}?api-version=7.1-preview.1"
        
        $InvokeSplat = @{
            URI    = $Uri
            Method = 'Patch'
        }

        if ($PSBoundParameters.ContainsKey('IsDisabled') -and ($false -eq $IsDisabled)) {
            # Enabling a repo needs to be done in a separate call before changing any other settings.
            $Body = [ordered]@{
                'isDisabled' = $IsDisabled
            }
            $InvokeSplat.Body = $Body | ConvertTo-Json -Compress
            try {
                InvokeADOPSRestMethod @InvokeSplat
            }
            catch {
                if (($_.ErrorDetails.Message | ConvertFrom-Json).message -eq 'The repository change is not supported.') {
                    Write-Warning 'Failed to enable the repo. This is most likely because it is already enabled.'
                }
                else {
                    throw $_
                }
            }
        }

        $Body = [ordered]@{}

        if (-Not [string]::IsNullOrEmpty($NewName)) {
            $Body.Add('name', $NewName)
        }

        if (-Not [string]::IsNullOrEmpty($DefaultBranch)) {
            if (-Not ($DefaultBranch -match '^\w+/\w+/\w+$')) {
                $DefaultBranch = "refs/heads/$DefaultBranch"
            }
            $Body.Add('defaultBranch', $DefaultBranch)
        }

        if ($body.Keys.Count -gt 0) {
            $InvokeSplat.Body = $Body | ConvertTo-Json -Compress
            try {
                InvokeADOPSRestMethod @InvokeSplat
            }
            catch {
                if (($_.ErrorDetails.Message | ConvertFrom-Json).message -like "TF401019*") {
                    Write-Warning 'Failed to update the repo. This may happen if the repo is disabled. Make sure it is enabled, or add -IsDisabled:$false'
                }
                else {
                    throw $_
                }
            }
        }
        
        if ($PSBoundParameters.ContainsKey('IsDisabled') -and ($true -eq $IsDisabled)) {
            # Disabling a repo needs to be done in a separate call and after any other changes.
            $Body = [ordered]@{
                'isDisabled' = $IsDisabled
            }
            $InvokeSplat.Body = $Body | ConvertTo-Json -Compress
            try {
                InvokeADOPSRestMethod @InvokeSplat
            }
            catch {
                if (($_.ErrorDetails.Message | ConvertFrom-Json).message -eq 'The repository change is not supported.') {
                    Write-Warning 'Failed to disable the repo. This is most likely because it is already disabled.'
                }
                else {
                    throw $_
                }
            }
        }
    }
}
#endregion Set-ADOPSRepository

#region Set-ADOPSServiceConnection

function Set-ADOPSServiceConnection {
    [CmdletBinding(DefaultParameterSetName = 'ServicePrincipal')]
    param (
        [Parameter()]
        [string]$Organization,
        
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$SubscriptionName,

        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(Mandatory)]
        [guid]$ServiceEndpointId,

        [Parameter()]
        [string]$ConnectionName,

        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$EndpointOperation,
      
        [Parameter(Mandatory, ParameterSetName = 'ServicePrincipal')]
        [pscredential]$ServicePrincipal,

        [Parameter(Mandatory, ParameterSetName = 'ManagedServiceIdentity')]
        [switch]$ManagedIdentity,

        [Parameter(Mandatory, ParameterSetName = 'WorkloadIdentityFederation')]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory, ParameterSetName = 'WorkloadIdentityFederation')]
        [string]$WorkloadIdentityFederationIssuer,

        [Parameter(Mandatory, ParameterSetName = 'WorkloadIdentityFederation')]
        [string]$WorkloadIdentityFederationSubject

    )
    
    process {

        # If user didn't specify org, get it from saved context
        if ([string]::IsNullOrEmpty($Organization)) {
            $Organization = GetADOPSDefaultOrganization
        }

        # Get ProjectId
        $ProjectInfo = Get-ADOPSProject -Organization $Organization -Project $Project

        # Set connection name if not set by parameter
        if (-not $ConnectionName) {
            $ConnectionName = $SubscriptionName -replace " "
        }

        switch ($PSCmdlet.ParameterSetName) {
        
            'ServicePrincipal' {
                $authorization = [ordered]@{
                    parameters = [ordered]@{
                        tenantid            = $TenantId
                        serviceprincipalid  = $ServicePrincipal.UserName
                        authenticationType  = "spnKey"
                        serviceprincipalkey = $ServicePrincipal.GetNetworkCredential().Password
                    }
                    scheme     = "ServicePrincipal"
                }
        
                $data = [ordered]@{
                    subscriptionId   = $SubscriptionId
                    subscriptionName = $SubscriptionName
                    environment      = "AzureCloud"
                    scopeLevel       = "Subscription"
                    creationMode     = "Manual"
                }
            }
    
            'ManagedServiceIdentity' {
                $authorization = [ordered]@{
                    parameters = [ordered]@{
                        tenantid = $TenantId
                    }
                    scheme     = "ManagedServiceIdentity"
                }
            }

            'WorkloadIdentityFederation' {
                $authorization = [ordered]@{
                    parameters = [ordered]@{
                        tenantid                          = $TenantId
                        serviceprincipalid                = $ServicePrincipalId
                        workloadIdentityFederationIssuer  = $WorkloadIdentityFederationIssuer
                        workloadIdentityFederationSubject = $WorkloadIdentityFederationSubject
                    }
                    scheme     = "WorkloadIdentityFederation"
                }
        
                $data = [ordered]@{
                    subscriptionId   = $SubscriptionId
                    subscriptionName = $SubscriptionName
                    environment      = "AzureCloud"
                    scopeLevel       = "Subscription"
                    creationMode     = "Manual"
                }
            }
        }

        # Create body for the API call
        $Body = [ordered]@{
            authorization                    = $authorization
            data                             = $data
            description                      = $Description
            id                               = $ServiceEndpointId
            isReady                          = $true
            isShared                         = $false
            name                             = $ConnectionName
            serviceEndpointProjectReferences = @(
                [ordered]@{
                    projectReference = [ordered]@{
                        id   = $ProjectInfo.Id
                        name = $Project
                    }
                    name             = $ConnectionName
                }
            )
            type                             = "AzureRM"
            url                              = "https://management.azure.com/"
        } | ConvertTo-Json -Depth 10
    
        if ($PSBoundParameters.ContainsKey('EndpointOperation')) {
            $URI = "https://dev.azure.com/$Organization/_apis/serviceendpoint/endpoints/$ServiceEndpointId`?operation=$EndpointOperation`&api-version=7.1-preview.4"
        }
        else {
            $URI = "https://dev.azure.com/$Organization/_apis/serviceendpoint/endpoints/$ServiceEndpointId`?api-version=7.1-preview.4"
        }
        
        $InvokeSplat = @{
            Uri    = $URI
            Method = "PUT"
            Body   = $Body
        }
    
        InvokeADOPSRestMethod @InvokeSplat
    }
}
#endregion Set-ADOPSServiceConnection

#region Start-ADOPSPipeline

function Start-ADOPSPipeline {
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter()]
        [string]$Branch = 'main',

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $AllPipelinesURI = "https://dev.azure.com/$Organization/$Project/_apis/pipelines?api-version=7.1-preview.1"
    $AllPipelines = InvokeADOPSRestMethod -Method Get -Uri $AllPipelinesURI
    $PipelineID = ($AllPipelines.value | Where-Object -Property Name -EQ $Name).id

    if ([string]::IsNullOrEmpty($PipelineID)) {
        throw "No pipeline with name $Name found."
    }

    if ($Branch -notmatch '^refs/.*') {
        $Branch = 'refs/heads/' + $Branch
    }
    $URI = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/$PipelineID/runs?api-version=7.1-preview.1"
    $Body = '{"stagesToSkip":[],"resources":{"repositories":{"self":{"refName":"' + $Branch + '"}}},"variables":{}}'
    
    $InvokeSplat = @{
        Method = 'Post' 
        Uri    = $URI 
        Body   = $Body
    }

    InvokeADOPSRestMethod @InvokeSplat
}
#endregion Start-ADOPSPipeline

#region Test-ADOPSYamlFile

function Test-ADOPSYamlFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(Mandatory)]
        [ValidateScript({
                $_ -match '.*\.y[aA]{0,1}ml$'
            }, ErrorMessage = 'Fileextension must be ".yaml" or ".yml"')]
        [string]$File,

        [Parameter(Mandatory)]
        [int]$PipelineId,

        [Parameter()]
        [string]$Organization
    )

    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://dev.azure.com/$Organization/$Project/_apis/pipelines/$PipelineId/runs?api-version=7.1-preview.1"

    $FileData = Get-Content $File -Raw

    $Body = @{
        previewRun         = $true
        templateParameters = @{}
        resources          = @{}
        yamlOverride       = $FileData
    } | ConvertTo-Json -Depth 10 -Compress
    
    $InvokeSplat = @{
        Uri    = $URI
        Method = 'Post'
        Body   = $Body
    }
    
    try {
        $Result = InvokeADOPSRestMethod @InvokeSplat
        Write-Output "$file validation success."
    } 
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.ErrorDetails.Message) {
            $r = $_.ErrorDetails.Message | ConvertFrom-Json
            if ($r.typeName -like '*PipelineValidationException*') {
                Write-Warning "Validation failed:`n$($r.message)"
            }
            else {
                throw $_
            }
        }
    }
}
#endregion Test-ADOPSYamlFile

function Get-ADOPSMembership {
    param ([Parameter()]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]
        $Descriptor,

        # The default value for direction is 'up' meaning return all memberships where the subject is a member (e.g. all groups the subject is a member of). Alternatively, passing the direction as 'down' will return all memberships where the subject is a container (e.g. all members of the subject group).
        [Parameter()]
        [string]
        [ValidateSet('up', 'down')]
        $Direction = 'up'
    )
    
    # If user didn't specify org, get it from saved context
    if ([string]::IsNullOrEmpty($Organization)) {
        $Organization = GetADOPSDefaultOrganization
    }

    $Uri = "https://vssps.dev.azure.com/$Organization/_apis/graph/Memberships/$Descriptor`?direction=$Direction&depth=1&api-version=7.2-preview.1"
    $Response = InvokeADOPSRestMethod -Uri $Uri -Method 'GET'

    switch ($Direction) {
        'up' {
            if ($Response.value.count -ne 0) {
            $Membership = $Response.value.containerDescriptor
} else {
$Membership = $Response.value
}
        }
        'down' {
            if ($Response.value.count -ne 0) {
$Membership = $Response.value.memberDescriptor
} else {
$Membership = $Response.value
}
            
        }
    }

    $Membership | ForEach-Object -begin {
        $Members = New-object System.Collections.ArrayList
    } -process {
        $MemberType = ($_).split('.')[0]
        $Identity = $_
        switch ($MemberType) {
            'aadgp' {
                Get-ADOPSGroup -Descriptor $Identity | ForEach-Object { $Members.Add($_) | Out-Null }
            }
            'vssgp' {
                Get-ADOPSGroup -Descriptor $Identity | ForEach-Object { $Members.Add($_) | Out-Null }
            }
            'aad' {
                Get-ADOPSUser -Descriptor $Identity | ForEach-Object { $Members.Add($_) | Out-Null }
            }
        }
    }

    Write-Output $Members
}