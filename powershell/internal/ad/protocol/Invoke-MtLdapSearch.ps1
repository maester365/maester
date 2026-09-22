function Invoke-MtLdapSearch {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $SearchBase,

        [ValidateSet('Base', 'OneLevel', 'Subtree')]
        [string] $Scope = 'Subtree',

        [string] $Filter = '(objectClass=*)',

        [string[]] $Attributes = @(),

        [int] $PageSize = 1000,

        [switch] $ReturnDirectoryEntry,

        [timespan] $Timeout
    )

    function ConvertTo-LdapFilterLiteral {
        param(
            [AllowNull()]
            [string] $Value
        )

        if ($null -eq $Value) {
            return $null
        }

        $builder = New-Object -TypeName System.Text.StringBuilder
        foreach ($character in $Value.ToCharArray()) {
            switch ($character) {
                '(' { [void]$builder.Append('\28') }
                ')' { [void]$builder.Append('\29') }
                '*' { [void]$builder.Append('\2a') }
                '\' { [void]$builder.Append('\5c') }
                ([char]0) { [void]$builder.Append('\00') }
                default { [void]$builder.Append($character) }
            }
        }

        return $builder.ToString()
    }

    function Convert-SearchEntry {
        param($Entry)

        $properties = [ordered]@{
            DistinguishedName = [string]$Entry.DistinguishedName
        }

        if ($null -eq $Entry.Attributes) {
            if ($ReturnDirectoryEntry.IsPresent) {
                $properties['DirectoryEntry'] = $Entry
            }

            return [PSCustomObject]$properties
        }

        $attributeNames = if ($Entry.Attributes -is [System.Collections.IDictionary]) {
            @($Entry.Attributes.Keys)
        }
        else {
            @($Entry.Attributes.AttributeNames)
        }

        foreach ($attributeName in $attributeNames) {
            $rawAttribute = if ($Entry.Attributes -is [System.Collections.IDictionary]) {
                $Entry.Attributes[$attributeName]
            }
            else {
                $Entry.Attributes[[string]$attributeName]
            }

            $convertedValues = [System.Collections.Generic.List[object]]::new()
            if ($rawAttribute -is [byte[]]) {
                $convertedValues.Add((ConvertFrom-MtLdapValue -Value $rawAttribute -AttributeName ([string]$attributeName))) | Out-Null
            }
            else {
                foreach ($rawValue in @($rawAttribute)) {
                    $convertedValues.Add((ConvertFrom-MtLdapValue -Value $rawValue -AttributeName ([string]$attributeName))) | Out-Null
                }
            }

            $properties[[string]$attributeName] = if ($convertedValues.Count -le 1) {
                if ($convertedValues.Count -eq 0) { $null } else { $convertedValues[0] }
            }
            else {
                @($convertedValues)
            }
        }

        if ($ReturnDirectoryEntry.IsPresent) {
            $properties['DirectoryEntry'] = $Entry
        }

        return [PSCustomObject]$properties
    }

    function Get-PageControlFromResponse {
        param($Response)

        foreach ($control in @($Response.Controls)) {
            if ($control -is [System.DirectoryServices.Protocols.PageResultResponseControl]) {
                return $control
            }

            if ($null -ne $control -and $control.PSObject.Properties['Cookie']) {
                return $control
            }
        }

        return $null
    }

    $results = [System.Collections.Generic.List[object]]::new()
    $requestedAttributes = [string[]]$Attributes
    if ($null -eq $requestedAttributes -or $requestedAttributes.Count -eq 0) {
        $requestedAttributes = $null
    }
    $searchScope = [System.DirectoryServices.Protocols.SearchScope]::$Scope
    $effectiveTimeout = if ($PSBoundParameters.ContainsKey('Timeout')) { $Timeout } else { $null }
    $pageCookie = [byte[]]@()

    do {
        $request = New-Object -TypeName System.DirectoryServices.Protocols.SearchRequest -ArgumentList @(
            $SearchBase,
            $Filter,
            $searchScope,
            $requestedAttributes
        )

        if ($null -ne $effectiveTimeout) {
            $request.TimeLimit = $effectiveTimeout
        }

        $pageControl = $null
        if ($PageSize -gt 0) {
            $pageControl = New-Object -TypeName System.DirectoryServices.Protocols.PageResultRequestControl -ArgumentList $PageSize
            $pageControl.Cookie = $pageCookie
            [void]$request.Controls.Add($pageControl)
        }

        try {
            $overrideProperty = $Connection.PSObject.Properties['MtSendRequestOverride']
            if ($null -ne $overrideProperty) {
                $response = & $overrideProperty.Value $request $effectiveTimeout
            }
            elseif ($null -ne $effectiveTimeout) {
                $response = $Connection.SendRequest($request, $effectiveTimeout)
            }
            else {
                $response = $Connection.SendRequest($request)
            }
        }
        catch [System.OperationCanceledException] {
            throw 'LDAP search was cancelled.'
        }
        catch [System.TimeoutException] {
            $timeoutText = if ($null -ne $effectiveTimeout) { $effectiveTimeout.ToString() } else { $Connection.Timeout.ToString() }
            throw "LDAP search timed out after $timeoutText."
        }
        catch {
            throw "LDAP search failed. $($_.Exception.Message)"
        }

        foreach ($entry in @($response.Entries)) {
            $results.Add((Convert-SearchEntry -Entry $entry)) | Out-Null
        }

        $pageResponseControl = Get-PageControlFromResponse -Response $response
        $pageCookie = if ($null -ne $pageResponseControl -and $null -ne $pageResponseControl.Cookie) {
            [byte[]]@($pageResponseControl.Cookie)
        }
        else {
            [byte[]]@()
        }
    }
    while ($PageSize -gt 0 -and $pageCookie.Length -gt 0)

    return @($results)
}
