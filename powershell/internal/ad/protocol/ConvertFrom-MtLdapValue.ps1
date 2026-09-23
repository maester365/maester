function ConvertFrom-MtLdapValue {
    [CmdletBinding()]
    [OutputType([byte[]], [datetime], [int], [PSCustomObject], [System.Security.Principal.SecurityIdentifier], [string], [timespan])]
    param(
        [AllowNull()]
        [Parameter(Mandatory)]
        [object] $Value,

        [string] $AttributeName
    )

    function Convert-ByteArrayToSidString {
        param(
            [byte[]] $SidBytes
        )

        if ($null -eq $SidBytes -or $SidBytes.Length -lt 8) {
            return $null
        }

        $revision = $SidBytes[0]
        $subAuthorityCount = $SidBytes[1]
        $identifierAuthority = [uint64]0
        for ($index = 2; $index -lt 8; $index++) {
            $identifierAuthority = ($identifierAuthority -shl 8) -bor $SidBytes[$index]
        }

        $sidParts = [System.Collections.Generic.List[string]]::new()
        $sidParts.Add('S') | Out-Null
        $sidParts.Add([string]$revision) | Out-Null
        $sidParts.Add([string]$identifierAuthority) | Out-Null

        for ($subAuthorityIndex = 0; $subAuthorityIndex -lt $subAuthorityCount; $subAuthorityIndex++) {
            $byteOffset = 8 + ($subAuthorityIndex * 4)
            if ($byteOffset + 3 -ge $SidBytes.Length) {
                break
            }

            $subAuthority = [BitConverter]::ToUInt32($SidBytes, $byteOffset)
            $sidParts.Add([string]$subAuthority) | Out-Null
        }

        return ($sidParts -join '-')
    }

    function Convert-StringBackedValue {
        param(
            [string] $InputValue,
            [string] $NormalizedAttributeName
        )

        if ([string]::IsNullOrEmpty($InputValue)) {
            return $InputValue
        }

        $intervalAttributes = @(
            'maxpwdage',
            'minpwdage',
            'lockoutduration',
            'msds-lockoutduration',
            'msds-maximumpasswordage',
            'msds-minimumpasswordage'
        )
        if ($NormalizedAttributeName -in $intervalAttributes) {
            $intervalValue = 0L
            if ([long]::TryParse($InputValue, [ref]$intervalValue)) {
                if ($intervalValue -eq [long]::MinValue) {
                    return $null
                }

                return [timespan]::FromTicks([Math]::Abs($intervalValue))
            }
        }

        $integerAttributes = @(
            'useraccountcontrol',
            'forestfunctionality',
            'domainfunctionality',
            'ms-ds-machineaccountquota',
            'lockoutthreshold',
            'minpwdlength',
            'pwdproperties',
            'pwdhistorylength',
            'objectversion',
            'msds-behavior-version',
            'primarygroupid',
            'admincount',
            'grouptype',
            'options',
            'trusttype',
            'trustdirection',
            'trustattributes',
            'gpoptions',
            'flags',
            'versionnumber',
            'msds-passwordsettingsprecedence',
            'msds-lockoutthreshold',
            'msds-minimumpasswordlength',
            'msds-passwordhistorylength',
            'msds-requiredforestbehaviorversion',
            'tombstonelifetime'
        )
        if ($NormalizedAttributeName -in $integerAttributes) {
            $convertedInt = 0
            if ([int]::TryParse($InputValue, [ref]$convertedInt)) {
                return $convertedInt
            }
        }

        if ($NormalizedAttributeName -in @('iscriticalsystemobject', 'enabledconnection', 'msds-passwordcomplexityenabled')) {
            $convertedBoolean = $false
            if ([bool]::TryParse($InputValue, [ref]$convertedBoolean)) {
                return $convertedBoolean
            }
        }

        $fileTimeAttributes = @(
            'accountexpires',
            'badpasswordtime',
            'lastlogoff',
            'lastlogon',
            'lastlogontimestamp',
            'pwdlastset'
        )
        if ($NormalizedAttributeName -in $fileTimeAttributes) {
            $fileTimeValue = 0L
            if ([long]::TryParse($InputValue, [ref]$fileTimeValue) -and $fileTimeValue -gt 0 -and $fileTimeValue -lt [datetime]::MaxValue.ToFileTimeUtc()) {
                return [datetime]::FromFileTimeUtc($fileTimeValue)
            }
        }

        $generalizedTimeAttributes = @(
            'whencreated',
            'whenchanged',
            'createtimestamp',
            'modifytimestamp'
        )
        if ($NormalizedAttributeName -in $generalizedTimeAttributes -or $InputValue -match '^[0-9]{14}\.0Z$' -or $InputValue -match '^[0-9]{14}Z$') {
            $normalizedValue = $InputValue -replace '\.0Z$', 'Z'
            $formats = @("yyyyMMddHHmmss'Z'")
            $parsedDate = [datetime]::MinValue
            if ([datetime]::TryParseExact($normalizedValue, $formats, [System.Globalization.CultureInfo]::InvariantCulture, ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal), [ref]$parsedDate)) {
                return $parsedDate.ToUniversalTime()
            }
        }

        return $InputValue
    }

    if ($null -eq $Value) {
        return $null
    }

    $normalizedAttributeName = if ([string]::IsNullOrWhiteSpace($AttributeName)) {
        [string]::Empty
    }
    else {
        $AttributeName.ToLowerInvariant()
    }

    if ($Value -is [byte[]]) {
        switch ($normalizedAttributeName) {
            { $_ -in @('objectsid', 'sidhistory', 'securityidentifier') } {
                try {
                    return New-Object System.Security.Principal.SecurityIdentifier -ArgumentList $Value, 0
                }
                catch {
                    $sidString = Convert-ByteArrayToSidString -SidBytes $Value
                    if (-not [string]::IsNullOrWhiteSpace($sidString)) {
                        return [PSCustomObject]@{ Value = $sidString }
                    }

                    return $Value
                }
            }
            { $_ -in @('objectguid', 'invocationid', 'msds-optionalfeatureguid') } {
                try {
                    return ([guid]::new($Value)).ToString()
                }
                catch {
                    return $Value
                }
            }
            'ntsecuritydescriptor' {
                try {
                    return ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $Value
                }
                catch {
                    return $Value
                }
            }
            default {
                $decodedString = [System.Text.Encoding]::UTF8.GetString($Value)
                if ($decodedString -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') {
                    return $Value
                }

                return $decodedString.TrimEnd([char]0)
            }
        }
    }

    if ($Value -is [System.Security.Principal.SecurityIdentifier]) {
        if ($normalizedAttributeName -in @('objectsid', 'sidhistory', 'securityidentifier')) {
            return $Value
        }

        return $Value.Value
    }

    if ($Value -is [guid]) {
        return $Value.ToString()
    }

    if ($Value -is [string]) {
        return Convert-StringBackedValue -InputValue $Value -NormalizedAttributeName $normalizedAttributeName
    }

    if ($normalizedAttributeName -eq 'useraccountcontrol') {
        return [int]$Value
    }

    if ($normalizedAttributeName -in @('maxpwdage', 'minpwdage', 'lockoutduration', 'msds-lockoutduration', 'msds-maximumpasswordage', 'msds-minimumpasswordage')) {
        $intervalValue = [long]$Value
        if ($intervalValue -eq [long]::MinValue) {
            return $null
        }

        return [timespan]::FromTicks([Math]::Abs($intervalValue))
    }

    return $Value
}
