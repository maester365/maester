function Invoke-MtADQueryCached {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Query,
        [Parameter(Mandatory)] [hashtable] $Operation,
        [Parameter(Mandatory)] [int] $PageSize,
        [Parameter(Mandatory)] [timespan] $Timeout
    )

    $evidence = $__MtSession.ADConnection
    if (-not (Test-MtConnection -Service ActiveDirectory) -or -not $evidence.ProtocolValidated -or
        [string]::IsNullOrWhiteSpace($evidence.ResolvedServer)) {
        throw 'Connect-Maester -Service ActiveDirectory must validate a target before running LDAP queries.'
    }
    if ($evidence.TlsMode -notin 'Ldaps', 'StartTls') { throw 'The validated AD session has no supported TLS mode.' }

    $base = $Query.SearchBase
    if ($null -ne $Query.NamingContext) {
        $base = $evidence.("$($Query.NamingContext)NamingContext")
        if ([string]::IsNullOrWhiteSpace($base)) { throw 'The selected naming context is unavailable on the connected server.' }
    }
    $target = [ordered]@{
        Server = $evidence.ResolvedServer.ToLowerInvariant()
        Port = if ($evidence.TlsMode -eq 'StartTls') { 389 } else { 636 }
        AuthenticationMode = $evidence.AuthenticationMode
        TlsMode = $evidence.TlsMode
        SkipCertificateCheck = [bool]$evidence.SkipCertificateCheck
    }
    $targetIdentity = $target | ConvertTo-Json -Compress
    $state = $__MtSession.ADCache['ADQueryState']
    if ($null -eq $state -or -not [object]::ReferenceEquals($state.ConnectionState, $evidence) -or
        -not [object]::ReferenceEquals($state.Credential, $__MtSession.ADCredential) -or $state.TargetIdentity -cne $targetIdentity) {
        $state = @{
            ConnectionState = $evidence
            Credential = $__MtSession.ADCredential
            TargetIdentity = $targetIdentity
            Results = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        }
        $__MtSession.ADCache['ADQueryState'] = $state
    }
    if ($Operation.ContainsKey('State') -and -not [object]::ReferenceEquals($Operation.State, $state)) {
        if ($null -ne $Operation.Connection) { $Operation.Connection.Dispose(); $Operation.Connection = $null }
    }
    $Operation.State = $state

    $request = [ordered]@{
        Target = $target
        SearchBase = [string]$base
        Scope = $Query.Scope
        Filter = $Query.Filter
        Attributes = [string[]]$Query.Attributes
        SecurityDescriptorFlags = if ($Query.PSObject.Properties['SecurityDescriptorFlags']) { [int]$Query.SecurityDescriptorFlags } else { $null }
        ContractVersion = 1
    }
    $json = $request | ConvertTo-Json -Depth 5 -Compress
    $key = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($json)))
    if (-not $state.Results.ContainsKey($key)) {
        if ($null -eq $Operation.Connection) {
            # Use validated, resolved evidence directly; never rediscover a DC behind a cache key.
            $Operation.Connection = New-MtAdProtocolConnection -ProtocolEvidence $evidence
        }
        $parameters = @{
            Connection = $Operation.Connection
            SearchBase = [string]$base
            Scope = $Query.Scope
            Filter = $Query.Filter
            Attributes = $Query.Attributes
            PageSize = $PageSize
            Timeout = $Timeout
            AsAttributeBag = $true
            RequireComplete = $true
        }
        if ($null -ne $request.SecurityDescriptorFlags) { $parameters.SecurityDescriptorFlags = $Query.SecurityDescriptorFlags }
        $previousErrorPreference = $ErrorActionPreference
        try {
            # Method/conversion errors must abort collection even when the caller uses Continue.
            $ErrorActionPreference = 'Stop'
            $entries = @(Invoke-MtLdapSearch @parameters | ForEach-Object {
                Complete-MtADQueryRange -Connection $Operation.Connection -Entry $_ -Timeout $Timeout
            })
        } catch {
            # Rethrow so the caller's script stops, rather than merely skipping the failed statement.
            throw
        } finally {
            $ErrorActionPreference = $previousErrorPreference
        }
        # Commit only after every page and every ranged attribute succeeds, including successful empty results.
        $state.Results[$key] = [pscustomobject]@{
            PSTypeName = 'Maester.AD.QueryResult'
            Request = [pscustomobject]$request
            CollectedAt = [datetime]::UtcNow
            Entries = [object[]]$entries
        }
    }
    return Copy-MtADQueryResult -Value $state.Results[$key]
}
