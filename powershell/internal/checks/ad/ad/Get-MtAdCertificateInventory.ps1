function Get-MtAdCertificateInventory {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)] $Configuration,

        [switch] $IncludeRawData
    )

    $rows = @()
    $roles = @(
        @{ Name = 'Enterprise CA'; Property = 'EnterpriseCAs' },
        @{ Name = 'Trusted root'; Property = 'TrustedRootCAs' },
        @{ Name = 'Intermediate'; Property = 'IntermediateCAs' },
        @{ Name = 'NTAuth'; Property = 'NtAuthCertificates' }
    )
    foreach ($role in $roles) {
        foreach ($entry in @($Configuration.($role.Property))) {
            $raw = $entry.cACertificate
            # A single DER certificate is a byte array, not an array of certificates.
            $values = [System.Collections.Generic.List[object]]::new()
            if ($raw -is [byte[]] -or $raw -is [string]) {
                $values.Add($raw)
            } elseif ($raw -is [array] -and $raw.Count -gt 0 -and @($raw | Where-Object { $_ -isnot [byte] }).Count -eq 0) {
                # A single LDAP binary attribute can be projected as an object array of bytes.
                $values.Add([byte[]]$raw)
            } elseif ($null -ne $raw) {
                foreach ($value in $raw) { $values.Add($value) }
            }
            foreach ($value in $values) {
                if ($null -eq $value) { continue }
                $bytes = if ($value -is [byte[]]) { $value } elseif ($value -is [string]) {
                    try { [Convert]::FromBase64String($value) } catch { throw "Invalid certificate encoding for $($role.Name) $($entry.Name)." }
                } else { throw "Unsupported certificate value for $($role.Name) $($entry.Name)." }
                try {
                    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$bytes)
                    $row = [pscustomobject]@{
                        Role = $role.Name
                        Name = [string]$entry.Name
                        Subject = $cert.Subject
                        Issuer = $cert.Issuer
                        NotBefore = $cert.NotBefore.ToString('yyyy-MM-dd')
                        NotAfter = $cert.NotAfter.ToString('yyyy-MM-dd')
                        Thumbprint = $cert.Thumbprint
                        Status = if ($cert.NotAfter -lt (Get-Date)) { 'Expired (review)' } elseif ($cert.NotBefore -gt (Get-Date)) { 'Not yet valid (review)' } else { 'Within validity dates' }
                    }
                    if ($IncludeRawData) { $row | Add-Member -NotePropertyName RawData -NotePropertyValue $cert.RawData }
                    $rows += $row
                } catch {
                    throw "Unable to parse public certificate for $($role.Name) $($entry.Name)."
                } finally {
                    if ($null -ne $cert) { $cert.Dispose(); $cert = $null }
                }
            }
        }
    }
    return $rows
}
