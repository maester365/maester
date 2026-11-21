function Complete-MtADQueryRange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.DirectoryServices.Protocols.LdapConnection] $Connection,
        [Parameter(Mandatory)] [object] $Entry,
        [Parameter(Mandatory)] [timespan] $Timeout
    )

    foreach ($key in @($Entry.Attributes.Keys)) {
        if ($key -notmatch ';') { continue }
        if ($key -notmatch '^([A-Za-z][A-Za-z0-9-]*);range=(\d+)-(\d+|\*)$') {
            throw 'LDAP returned an unsupported attribute option.'
        }
        $attribute = $matches[1]
        $values = [System.Collections.Generic.List[object]]::new()
        $expectedStart = 0L
        $rangeKey = $key
        $rangeBag = $Entry.Attributes
        # AD can return an empty base attribute alongside the populated range.
        # Only a populated base attribute conflicts with the ranged values.
        if ($Entry.Attributes.Contains($attribute) -and $Entry.Attributes[$attribute].Count -gt 0) {
            throw 'LDAP returned ambiguous ranged and non-ranged values.'
        }

        while ($true) {
            if ($rangeKey -notmatch ('^' + [regex]::Escape($attribute) + ';range=(\d+)-(\d+|\*)$')) {
                throw 'LDAP returned an invalid attribute range.'
            }
            $start = [long]$matches[1]
            $end = $matches[2]
            if ($start -ne $expectedStart) { throw 'LDAP attribute range was not contiguous.' }
            $chunk = $rangeBag[$rangeKey]
            if ($end -ne '*' -and ([long]$end -lt $start -or $chunk.Count -ne ([long]$end - $start + 1))) {
                throw 'LDAP attribute range length did not match its bounds.'
            }
            foreach ($value in $chunk) { $values.Add($value) }
            if ($end -eq '*') { break }
            $expectedStart = [long]$end + 1
            $continuation = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $Entry.DistinguishedName -Scope Base `
                -Filter '(objectClass=*)' -Attributes @("$attribute`;range=$expectedStart-*") -PageSize 0 `
                -Timeout $Timeout -AsAttributeBag -RequireComplete)
            if ($continuation.Count -ne 1 -or $continuation[0].DistinguishedName -ine $Entry.DistinguishedName) {
                throw 'LDAP attribute range continuation did not return the original entry.'
            }
            $rangeBag = $continuation[0].Attributes
            $rangeKeys = @($rangeBag.Keys | Where-Object { $_ -like "$attribute`;range=*" })
            if ($rangeKeys.Count -ne 1) { throw 'LDAP attribute range continuation was missing or ambiguous.' }
            $rangeKey = $rangeKeys[0]
        }
        $Entry.Attributes.Remove($key)
        $Entry.Attributes[$attribute] = [object[]]$values.ToArray()
    }
    return $Entry
}
