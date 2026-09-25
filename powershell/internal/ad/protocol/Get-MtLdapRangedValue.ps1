function Get-MtLdapRangedValue {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $DistinguishedName,

        [Parameter(Mandatory)]
        [string] $AttributeName
    )

    function ConvertTo-LdapFilterLiteral {
        param([string] $Value)

        if ($null -eq $Value) {
            return $null
        }

        return ($Value -replace '\\', '\5c' -replace '\*', '\2a' -replace '\(', '\28' -replace '\)', '\29' -replace [char]0, '\00')
    }

    $values = [System.Collections.Generic.List[object]]::new()
    $rangeStart = 0
    $isComplete = $false
    $escapedDn = ConvertTo-LdapFilterLiteral -Value $DistinguishedName

    while (-not $isComplete) {
        $requestedAttribute = '{0};range={1}-*' -f $AttributeName, $rangeStart
        $entry = Invoke-MtLdapSearch -Connection $Connection -SearchBase $DistinguishedName -Scope Base -Filter "(&(objectClass=*)(distinguishedName=$escapedDn))" -Attributes @($requestedAttribute) -PageSize 0 | Select-Object -First 1
        if ($null -eq $entry) {
            break
        }

        $rangeProperty = $entry.PSObject.Properties |
            Where-Object {
                $_.Name -ieq $AttributeName -or $_.Name -imatch ('^{0};range=' -f [regex]::Escape($AttributeName))
            } |
            Select-Object -First 1

        if ($null -eq $rangeProperty -or $null -eq $rangeProperty.Value) {
            break
        }

        foreach ($item in @($rangeProperty.Value)) {
            $values.Add($item) | Out-Null
        }

        if ($rangeProperty.Name -imatch ';range=\d+-\*$') {
            $isComplete = $true
            continue
        }

        if ($rangeProperty.Name -imatch ';range=\d+-(\d+)$') {
            $rangeStart = ([int]$matches[1]) + 1
            continue
        }

        $isComplete = $true
    }

    return @($values)
}
