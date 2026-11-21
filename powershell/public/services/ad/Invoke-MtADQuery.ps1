function Invoke-MtADQuery {
    <#
    .SYNOPSIS
    Runs an arbitrary, read-only LDAP query with per-session result caching.
    .DESCRIPTION
    Queries the domain controller validated by Connect-Maester -Service ActiveDirectory.
    Accepts reusable New-MtADQuery objects, dictionaries or direct query parameters. Completes
    paging and ranged attributes before caching or returning any rows. Failures throw and are not cached.
    Returns entries with DistinguishedName and an Attributes dictionary whose values are always arrays.
    Absent attributes are omitted; absence cannot distinguish unset values from insufficient permissions.
    Known SIDs are strings, known GUIDs are GUID values, and security descriptors/unknown binary stay byte arrays.
    Standard text, numeric and date attributes are decoded by name. Unrecognized server attributes stay bytes,
    even when their syntax is text; schema-driven decoding is not provided. FILETIME 0/never sentinels stay integers.
    Uses one private connection per invocation, reused across pipeline queries and disposed even if stopped early.
    Cache hits return independent copies without opening a connection. A full AD cache reset or a new Maester run
    clears these results; legacy category-scoped resets do not. No cache bypass is offered.
    .PARAMETER Query
    Query definition, dictionary or PSCustomObject. May be supplied through the pipeline.
    .PARAMETER Name
    Optional starter query: User, Computer, Group, OrganizationalUnit or Gpo.
    .PARAMETER SearchBase
    Explicit distinguished name. An empty string selects RootDSE with Scope Base.
    .PARAMETER NamingContext
    Default, Configuration or Schema naming context. Defaults to Default; cannot be combined with SearchBase.
    .PARAMETER Scope
    Base, OneLevel or Subtree. Defaults to Subtree.
    .PARAMETER Filter
    Raw LDAP filter. Escape interpolated values with ConvertTo-MtLdapFilterValue.
    .PARAMETER Attributes
    Explicit LDAP display names. Required unless Name supplies a starter selection.
    Wildcards, OIDs, options and known password/recovery-secret attributes are rejected.
    .PARAMETER SecurityDescriptorFlags
    Optional LDAP security descriptor control flags. Returned descriptors remain binary.
    .PARAMETER PageSize
    LDAP page size, from 1 to 1000. All pages are collected; this does not limit total results.
    .PARAMETER Timeout
    Positive time limit per LDAP request. Defaults to 30 seconds; not an overall collection deadline.
    .PARAMETER AsResult
    Returns a result envelope containing Entries, Request and CollectedAt instead of individual entries.
    .EXAMPLE
    Invoke-MtADQuery -Name User

    Collects starter user attributes once and reuses the complete query result for the session.
    .EXAMPLE
    New-MtADQuery -Name Group -Attributes name,member | Invoke-MtADQuery -AsResult

    Collects complete group membership, including LDAP range continuations, with request metadata.
    .LINK
    https://maester.dev/docs/commands/Invoke-MtADQuery
    #>
    [CmdletBinding(DefaultParameterSetName = 'Parameters')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Query')]
        [ValidateNotNull()]
        [object] $Query,
        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateSet('User', 'Computer', 'Group', 'OrganizationalUnit', 'Gpo')]
        [string] $Name,
        [Parameter(ParameterSetName = 'Parameters')]
        [AllowEmptyString()]
        [string] $SearchBase,
        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateSet('Default', 'Configuration', 'Schema')]
        [string] $NamingContext = 'Default',
        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateSet('Base', 'OneLevel', 'Subtree')]
        [string] $Scope = 'Subtree',
        [Parameter(ParameterSetName = 'Parameters')]
        [ValidateNotNullOrEmpty()]
        [string] $Filter = '(objectClass=*)',
        [Parameter(ParameterSetName = 'Parameters')]
        [string[]] $Attributes,
        [Parameter(ParameterSetName = 'Parameters')]
        [System.DirectoryServices.SecurityMasks] $SecurityDescriptorFlags,
        [ValidateRange(1, 1000)]
        [int] $PageSize = 1000,
        [ValidateScript({ $_ -gt [timespan]::Zero })]
        [timespan] $Timeout = [timespan]::FromSeconds(30),
        [switch] $AsResult
    )
    begin {
        Write-Verbose 'Running Active Directory queries through the session result cache.'
        $operation = @{ Connection = $null }
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Query') {
            $definition = Resolve-MtADQuery -Query $Query
        } else {
            $parameters = @{}
            foreach ($field in 'Name', 'SearchBase', 'NamingContext', 'Scope', 'Filter', 'Attributes', 'SecurityDescriptorFlags') {
                if ($PSBoundParameters.ContainsKey($field)) { $parameters[$field] = $PSBoundParameters[$field] }
            }
            $definition = New-MtADQuery @parameters
        }
        $result = Invoke-MtADQueryCached -Query $definition -Operation $operation -PageSize $PageSize -Timeout $Timeout
        if ($AsResult) { $result } else { $result.Entries }
    }
    clean {
        if ($null -ne $operation.Connection) { $operation.Connection.Dispose() }
    }
}
