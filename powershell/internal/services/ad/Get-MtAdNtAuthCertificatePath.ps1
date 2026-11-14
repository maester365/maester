function Get-MtAdNtAuthCertificatePath {
    <#
    .SYNOPSIS
    Builds offline NTAuth CA certificate paths using the published AD CA inventory.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [AllowNull()] [PSCustomObject] $Configuration
    )

    $config = Get-MtAdConfigurationInventory -State ([pscustomobject]@{ Configuration = $Configuration }) -Required NtAuthCertificates
    $hasCertificate = $false
    foreach ($entry in @($config.NtAuthCertificates)) {
        if ($null -eq $entry -or $null -eq $entry.PSObject.Properties['cACertificate']) {
            throw 'NTAuth certificate attributes were not collected.'
        }
        if ($null -ne $entry.cACertificate -and @($entry.cACertificate).Count -gt 0) { $hasCertificate = $true }
    }
    if (-not $hasCertificate) { return }

    $roles = @('EnterpriseCAs', 'TrustedRootCAs', 'IntermediateCAs', 'NtAuthCertificates')
    $config = Get-MtAdConfigurationInventory -State ([pscustomobject]@{ Configuration = $config }) -Required $roles
    foreach ($role in $roles) {
        foreach ($entry in @($config.$role)) {
            if ($null -eq $entry -or $null -eq $entry.PSObject.Properties['cACertificate']) {
                throw "Published $role certificate attributes were not collected."
            }
        }
    }

    # Reuse the parser and binary-value handling of AD-CFG-15/21, retaining only public DER data.
    $records = @(Get-MtAdCertificateInventory -Configuration $config -IncludeRawData)
    $certificates = @{}
    $roots = @{}
    $targets = @{}
    try {
        foreach ($record in $records) {
            $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$record.RawData)
            $id = $cert.GetCertHashString([Security.Cryptography.HashAlgorithmName]::SHA256)
            if ($certificates.ContainsKey($id)) { $cert.Dispose() }
            else { $certificates[$id] = $cert }
            if ($record.Role -eq 'Trusted root') { $roots[$id] = $true }
            if ($record.Role -eq 'NTAuth') { $targets[$id] = $record }
        }

        foreach ($id in @($targets.Keys | Sort-Object)) {
            $cert = $certificates[$id]
            $chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
            try {
                $policy = $chain.ChainPolicy
                $policy.TrustMode = [Security.Cryptography.X509Certificates.X509ChainTrustMode]::CustomRootTrust
                $policy.DisableCertificateDownloads = $true
                $policy.RevocationMode = [Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
                $policy.VerificationFlags = [Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
                foreach ($rootId in $roots.Keys) { [void]$policy.CustomTrustStore.Add($certificates[$rootId]) }
                foreach ($known in $certificates.Values) { [void]$policy.ExtraStore.Add($known) }

                $built = $chain.Build($cert)
                $issues = [Collections.Generic.List[string]]::new()
                foreach ($status in $chain.ChainStatus) { $issues.Add($status.Status.ToString()) }
                $path = @($chain.ChainElements | ForEach-Object {
                        [pscustomobject]@{
                            Subject = $_.Certificate.Subject
                            Thumbprint = $_.Certificate.Thumbprint
                            CertificateId = $_.Certificate.GetCertHashString([Security.Cryptography.HashAlgorithmName]::SHA256)
                        }
                    })

                # Custom roots prevent ambient root trust; this also rejects intermediates supplied by OS caches.
                $unpublished = @($path | Where-Object { -not $certificates.ContainsKey($_.CertificateId) })
                if ($unpublished.Count -gt 0) { $issues.Add('PathUsesCertificateOutsidePublishedInventory') }
                $root = if ($path.Count -gt 0 -and $roots.ContainsKey($path[-1].CertificateId)) { $path[-1] } else { $null }
                if ($null -eq $root) { $issues.Add('NoPublishedTrustAnchor') }

                # Build treats its input as an end certificate, so explicitly require an NTAuth CA certificate.
                $basic = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' } | Select-Object -First 1
                $isCa = $null -ne $basic -and ([Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($basic, $basic.Critical)).CertificateAuthority
                if (-not $isCa) { $issues.Add('NtAuthCertificateIsNotCa') }
                $usage = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.15' } | Select-Object -First 1
                if ($null -ne $usage) {
                    $keyUsage = ([Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($usage, $usage.Critical)).KeyUsages
                    if (($keyUsage -band [Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyCertSign) -eq 0) { $issues.Add('NtAuthCertificateCannotSignCertificates') }
                }

                # The chain engine treats the target as an end entity. Include a non-self-issued CA
                # target when checking the number of subordinate CAs allowed by issuer constraints.
                $subordinateCas = 0
                foreach ($element in $chain.ChainElements) {
                    $constraints = $element.Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' } | Select-Object -First 1
                    if ($null -ne $constraints) {
                        $decoded = [Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($constraints, $constraints.Critical)
                        if ($decoded.HasPathLengthConstraint -and $subordinateCas -gt $decoded.PathLengthConstraint) {
                            $issues.Add('CaPathLengthConstraintExceeded')
                        }
                        if ($decoded.CertificateAuthority -and $element.Certificate.Subject -ne $element.Certificate.Issuer) { $subordinateCas++ }
                    }
                }

                $verified = $built -and $issues.Count -eq 0
                [pscustomobject]@{
                    Subject = $cert.Subject
                    Thumbprint = $cert.Thumbprint
                    CertificateId = $id
                    Verified = $verified
                    Status = if ($verified) { 'Verified' } else { 'NotVerified' }
                    Issues = @($issues.ToArray() | Sort-Object -Unique)
                    RootSubject = if ($root) { $root.Subject } else { $null }
                    RootThumbprint = if ($root) { $root.Thumbprint } else { $null }
                    Path = $path
                    RevocationChecked = $false
                    CertificateDownloadsEnabled = $false
                }
            } finally {
                $chain.Dispose()
            }
        }
    } finally {
        foreach ($cert in $certificates.Values) { $cert.Dispose() }
    }
}
