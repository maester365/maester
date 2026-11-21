function ConvertFrom-MtADQueryEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Entry,
        [Parameter(Mandatory)] [string[]] $Attributes
    )

    $bag = [ordered]@{}
    $requestedNames = @($Attributes | ForEach-Object { ($_ -split ';')[0].ToLowerInvariant() })
    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    # DirectoryAttribute enumeration exposes the server's bytes, even for textual values.
    # Decode by known attribute semantics, never by whether unknown bytes happen to be valid UTF-8.
    $textNames = @(
        'name', 'cn', 'samaccountname', 'displayname', 'dnshostname', 'description', 'member', 'memberof',
        'gplink', 'gpcfilesyspath', 'ldapdisplayname', 'serviceprincipalname', 'objectclass', 'distinguishedname',
        'defaultnamingcontext', 'configurationnamingcontext', 'schemanamingcontext', 'rootdomainnamingcontext',
        'namingcontexts', 'supportedldapversion', 'supportedsaslmechanisms', 'supportedcontrol',
        'operatingsystem', 'operatingsystemversion', 'managedby', 'manager', 'homedirectory', 'profilepath',
        'scriptpath', 'userworkstations', 'location', 'dnsroot', 'ncname', 'netbiosname', 'trustpartner',
        'fsmoroleowner', 'serverreference', 'fromserver', 'transporttype', 'siteobject', 'gpcwqlfilter',
        'msds-allowedtodelegateto', 'msds-psoappliesto'
    )
    $fileTimeNames = @('accountexpires', 'badpasswordtime', 'lastlogoff', 'lastlogon', 'lastlogontimestamp', 'pwdlastset')
    $convertedNames = @(
        'useraccountcontrol', 'forestfunctionality', 'domainfunctionality', 'ms-ds-machineaccountquota',
        'lockoutthreshold', 'minpwdlength', 'pwdproperties', 'pwdhistorylength', 'objectversion',
        'msds-behavior-version', 'primarygroupid', 'admincount', 'grouptype', 'options', 'trusttype',
        'trustdirection', 'trustattributes', 'gpoptions', 'flags', 'versionnumber', 'msds-passwordsettingsprecedence',
        'msds-lockoutthreshold', 'msds-minimumpasswordlength', 'msds-passwordhistorylength',
        'msds-requiredforestbehaviorversion', 'tombstonelifetime', 'iscriticalsystemobject', 'enabledconnection',
        'msds-passwordcomplexityenabled', 'msds-isrodc', 'maxpwdage', 'minpwdage', 'lockoutduration',
        'msds-lockoutduration', 'msds-maximumpasswordage', 'msds-minimumpasswordage',
        'whencreated', 'whenchanged', 'createtimestamp', 'modifytimestamp'
    ) + $fileTimeNames
    $names = if ($Entry.Attributes -is [System.Collections.IDictionary]) { @($Entry.Attributes.Keys) }
    else { @($Entry.Attributes.AttributeNames) }
    foreach ($name in $names) {
        $baseName = ([string]$name -split ';')[0].ToLowerInvariant()
        if ($requestedNames -notcontains $baseName) { continue }
        $values = [System.Collections.Generic.List[object]]::new()
        $rawAttribute = $Entry.Attributes[[string]$name]
        if ($rawAttribute -is [byte[]]) { $rawValues = ,$rawAttribute }
        else { $rawValues = @($rawAttribute) }
        foreach ($raw in $rawValues) {
            if ($raw -is [byte[]] -and $baseName -in ($textNames + $convertedNames)) {
                $raw = $utf8.GetString($raw)
            }
            if ($raw -is [byte[]]) {
                if ($baseName -in 'objectguid', 'invocationid', 'msds-optionalfeatureguid' -and $raw.Length -eq 16) {
                    $value = [guid]::new($raw)
                } elseif ($baseName -in 'objectsid', 'sidhistory', 'securityidentifier', 'ms-ds-creatorsid') {
                    # All these attributes carry SID bytes. Reuse the base SID converter without
                    # depending on newer legacy collectors recognizing each attribute alias.
                    $sid = ConvertFrom-MtLdapValue -Value $raw -AttributeName 'objectSid'
                    if ($sid -is [byte[]]) { $value = $raw.Clone() }
                    else { $value = [string]$sid.Value }
                } else {
                    # Unknown binary and security descriptors are never guessed to be UTF-8 strings.
                    $value = $raw.Clone()
                }
            } elseif ($raw -is [string]) {
                $sentinel = 0L
                if ($baseName -in $fileTimeNames -and [long]::TryParse($raw, [ref]$sentinel) -and
                    $sentinel -in 0L, [long]::MaxValue) {
                    # Keep AD's unset/never FILETIME sentinels distinguishable from an absent attribute.
                    $value = $sentinel
                } elseif ($baseName -in $convertedNames) {
                    $value = ConvertFrom-MtLdapValue -Value $raw -AttributeName $baseName
                } else {
                    # No generalized-date guessing for text or unrecognized names.
                    $value = $raw
                }
            } else { $value = $raw }
            $values.Add($value)
        }
        $bag[([string]$name).ToLowerInvariant()] = [object[]]$values.ToArray()
    }
    return [pscustomobject]@{
        PSTypeName = 'Maester.AD.Entry'
        DistinguishedName = [string]$Entry.DistinguishedName
        Attributes = $bag
    }
}
