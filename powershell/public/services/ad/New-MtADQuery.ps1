function New-MtADQuery {
    <#
    .SYNOPSIS
    Creates a reusable, validated LDAP query definition.
    .DESCRIPTION
    Builds a query object for Invoke-MtADQuery without connecting to Active Directory.
    Named definitions are small starter queries, not replacements for legacy collector output.
    Only explicit LDAP display names are accepted. Wildcards, OIDs, attribute options and known
    password/recovery-secret attributes are rejected. This prevents accidental secret collection;
    it is not an authorization boundary. Raw filters must not contain untrusted, unescaped values.
    .PARAMETER Name
    Optional starter definition: User, Computer, Group, OrganizationalUnit or Gpo.
    .PARAMETER SearchBase
    An explicit distinguished name. An empty string selects RootDSE; use Scope Base for RootDSE.
    Cannot be combined with an explicit NamingContext.
    .PARAMETER NamingContext
    The connected server's Default, Configuration or Schema naming context. Defaults to Default.
    .PARAMETER Scope
    LDAP search scope: Base, OneLevel or Subtree. Defaults to Subtree.
    .PARAMETER Filter
    Raw LDAP filter. Defaults to the named definition's filter, or (objectClass=*).
    Use ConvertTo-MtLdapFilterValue for interpolated assertion values.
    .PARAMETER Attributes
    Explicit attributes to collect. Overrides a named definition's selection. Required for custom queries.
    .PARAMETER SecurityDescriptorFlags
    Optional Owner, Group, Dacl or Sacl flags for the LDAP security descriptor control.
    Security descriptors are returned as binary values, not parsed objects.
    .EXAMPLE
    New-MtADQuery -Name User

    Creates the starter User query without contacting a domain controller.
    .EXAMPLE
    New-MtADQuery -NamingContext Schema -Filter '(objectClass=attributeSchema)' -Attributes name,lDAPDisplayName

    Defines a query against the connected server's schema partition.
    .LINK
    https://maester.dev/docs/commands/New-MtADQuery
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory query definition without changing the directory or session.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateSet('User', 'Computer', 'Group', 'OrganizationalUnit', 'Gpo')]
        [string] $Name,
        [AllowEmptyString()]
        [string] $SearchBase,
        [ValidateSet('Default', 'Configuration', 'Schema')]
        [string] $NamingContext = 'Default',
        [ValidateSet('Base', 'OneLevel', 'Subtree')]
        [string] $Scope = 'Subtree',
        [ValidateNotNullOrEmpty()]
        [string] $Filter = '(objectClass=*)',
        [string[]] $Attributes,
        [System.DirectoryServices.SecurityMasks] $SecurityDescriptorFlags
    )

    Write-Verbose 'Creating a validated Active Directory query definition.'
    if ($PSBoundParameters.ContainsKey('SearchBase') -and $PSBoundParameters.ContainsKey('NamingContext')) {
        throw 'Specify SearchBase or NamingContext, not both.'
    }
    if ($Name) {
        $definition = Get-MtADQueryDefinition -Name $Name
        if (-not $PSBoundParameters.ContainsKey('Filter')) { $Filter = $definition.Filter }
        if (-not $PSBoundParameters.ContainsKey('Attributes')) { $Attributes = $definition.Attributes }
    }
    if (-not $Attributes -or $Attributes.Count -eq 0) {
        throw 'Select explicit Attributes or use a named query definition.'
    }
    foreach ($attribute in $Attributes) {
        if ($attribute -notmatch '^[A-Za-z][A-Za-z0-9-]*$') {
            throw 'Attributes must be explicit LDAP display names without wildcards, OIDs or options.'
        }
        if ($attribute -imatch '^(ms-Mcs-AdmPwd|msLAPS-Password|msLAPS-EncryptedPassword.*|msLAPS-EncryptedDSRMPassword.*|msDS-ManagedPassword|unicodePwd|dBCSPwd|ntPwdHistory|lmPwdHistory|supplementalCredentials|userPassword|unixUserPassword|msSFU30Password|msFVE-RecoveryPassword|msFVE-KeyPackage|msTPM-OwnerInformation|msPKIAccountCredentials|msPKIDPAPIMasterKeys|currentValue|priorValue|trustAuthIncoming|trustAuthOutgoing|initialAuthIncoming|initialAuthOutgoing)$') {
            throw 'Password and recovery-secret attributes are not supported by the cached query API.'
        }
    }
    if ($PSBoundParameters.ContainsKey('SearchBase') -and $SearchBase.Length -eq 0 -and $Scope -ne 'Base') {
        throw 'An empty SearchBase (RootDSE) requires Scope Base.'
    }
    $query = [ordered]@{
        PSTypeName = 'Maester.AD.Query'
        NamingContext = if ($PSBoundParameters.ContainsKey('SearchBase')) { $null } else { $NamingContext }
        SearchBase = if ($PSBoundParameters.ContainsKey('SearchBase')) { $SearchBase } else { $null }
        Scope = $Scope
        Filter = $Filter
        Attributes = [string[]]@($Attributes | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
    }
    if ($PSBoundParameters.ContainsKey('SecurityDescriptorFlags')) {
        $query['SecurityDescriptorFlags'] = $SecurityDescriptorFlags
    }
    return [pscustomobject]$query
}
