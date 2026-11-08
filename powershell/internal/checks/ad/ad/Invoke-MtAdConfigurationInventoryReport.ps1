function Invoke-MtAdConfigurationInventoryReport {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][ValidateSet('EnterpriseCAs', 'Templates', 'Certificates', 'CDP', 'NTAuth', 'SiteLinks')][string] $Kind)

    $required = switch ($Kind) {
        'EnterpriseCAs' { @('EnterpriseCAs') }
        'Templates' { @('EnterpriseCAs', 'CertificateTemplates', 'EnrollmentTemplates') }
        'Certificates' { @('EnterpriseCAs', 'TrustedRootCAs', 'IntermediateCAs') }
        'CDP' { @('CrlDistributionPoints') }
        'NTAuth' { @('NtAuthCertificates') }
        'SiteLinks' { @('SiteLinks') }
    }
    $config = Get-MtAdConfigurationInventory -State (Get-MtADDomainState -Categories @('Configuration')) -Required $required
    $lines = [System.Collections.Generic.List[string]]::new()
    switch ($Kind) {
        'EnterpriseCAs' {
            $cas = @($config.EnterpriseCAs)
            $lines.Add("Enterprise CAs: $($cas.Count). Review the published templates and host names below.")
            $lines.Add('| CA | DNS host | Published templates |')
            $lines.Add('| --- | --- | --- |')
            foreach ($ca in $cas) {
                $templates = @($ca.certificateTemplates | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
                $lines.Add("| $(ConvertTo-MtAdConfigurationInventoryCell $ca.Name) | $(ConvertTo-MtAdConfigurationInventoryCell $ca.dNSHostName) | $(ConvertTo-MtAdConfigurationInventoryCell ($templates -join ', ')) |")
            }
        }
        'Templates' {
            $templates = @($config.CertificateTemplates)
            $published = @($config.EnrollmentTemplates | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)
            $known = @{}
            foreach ($template in $templates) { $known[[string]$template.Name] = $true }
            $unknown = @($published | Where-Object { -not $known.ContainsKey([string]$_) })
            $lines.Add("Template objects: $($templates.Count); distinct published names: $($published.Count); published names without a template object: $($unknown.Count).")
            $lines.Add('| Template CN | Display name | Publishing CAs |')
            $lines.Add('| --- | --- | --- |')
            foreach ($template in $templates) {
                $publishers = @($config.EnterpriseCAs | Where-Object { @($_.certificateTemplates) -contains $template.Name } | ForEach-Object { $_.Name })
                $lines.Add("| $(ConvertTo-MtAdConfigurationInventoryCell $template.Name) | $(ConvertTo-MtAdConfigurationInventoryCell $template.displayName) | $(ConvertTo-MtAdConfigurationInventoryCell ($publishers -join ', ')) |")
            }
            foreach ($name in $unknown) {
                $publishers = @($config.EnterpriseCAs | Where-Object { @($_.certificateTemplates) -contains $name } | ForEach-Object { $_.Name })
                $lines.Add("| $(ConvertTo-MtAdConfigurationInventoryCell $name) (unknown template) | — | $(ConvertTo-MtAdConfigurationInventoryCell ($publishers -join ', ')) |")
            }
        }
        'Certificates' {
            $certs = @(Get-MtAdCertificateInventory -Configuration $config)
            $lines.Add("Enterprise CA objects: $(@($config.EnterpriseCAs).Count); trusted root objects: $(@($config.TrustedRootCAs).Count); intermediate objects: $(@($config.IntermediateCAs).Count); public certificate entries: $($certs.Count). A certificate in multiple roles appears once per role.")
            $lines.Add('| Role | Object | Subject | Issuer | Valid from | Valid to | Thumbprint | Observation |')
            $lines.Add('| --- | --- | --- | --- | --- | --- | --- | --- |')
            foreach ($cert in $certs) {
                $lines.Add("| $(ConvertTo-MtAdConfigurationInventoryCell $cert.Role) | $(ConvertTo-MtAdConfigurationInventoryCell $cert.Name) | $(ConvertTo-MtAdConfigurationInventoryCell $cert.Subject) | $(ConvertTo-MtAdConfigurationInventoryCell $cert.Issuer) | $($cert.NotBefore) | $($cert.NotAfter) | $($cert.Thumbprint) | $($cert.Status) |")
            }
        }
        'CDP' {
            $entries = @($config.CrlDistributionPoints)
            $lines.Add("CRL distribution point objects: $($entries.Count). This is an inventory, not a CRL validity or reachability check.")
            $lines.Add('| Name | Distinguished name | CRL published |')
            $lines.Add('| --- | --- | --- |')
            foreach ($entry in $entries) {
                $present = if ($null -ne $entry.certificateRevocationList -and @($entry.certificateRevocationList).Count -gt 0) { 'Yes' } else { 'No' }
                $lines.Add("| $(ConvertTo-MtAdConfigurationInventoryCell $entry.Name) | $(ConvertTo-MtAdConfigurationInventoryCell $entry.DistinguishedName) | $present |")
            }
        }
        'NTAuth' {
            $certs = @(Get-MtAdCertificateInventory -Configuration $config)
            $ntAuth = @($certs | Where-Object { $_.Role -eq 'NTAuth' })
            $lines.Add("NTAuth objects: $(@($config.NtAuthCertificates).Count); public certificates: $($ntAuth.Count). Expiry observations require review and do not fail this inventory.")
            $lines.Add('| Object | Subject | Issuer | Valid from | Valid to | Thumbprint | Observation |')
            $lines.Add('| --- | --- | --- | --- | --- | --- | --- |')
            foreach ($cert in $ntAuth) {
                $lines.Add("| $(ConvertTo-MtAdConfigurationInventoryCell $cert.Name) | $(ConvertTo-MtAdConfigurationInventoryCell $cert.Subject) | $(ConvertTo-MtAdConfigurationInventoryCell $cert.Issuer) | $($cert.NotBefore) | $($cert.NotAfter) | $($cert.Thumbprint) | $($cert.Status) |")
            }
        }
        'SiteLinks' {
            $links = @(Get-MtAdConfigurationInventorySiteLinkTransport -Configuration $config)
            $ip = @($links | Where-Object { $_.Transport -eq 'IP' }).Count
            $smtp = @($links | Where-Object { $_.Transport -eq 'SMTP' }).Count
            $lines.Add("Site links: $($links.Count); IP: $ip; SMTP: $smtp. Transport is identified by the parent DN, not cost or replication interval.")
            $lines.Add('| Link | Transport | Cost | Replication interval (minutes) | Sites | Distinguished name |')
            $lines.Add('| --- | --- | --- | --- | --- | --- |')
            foreach ($link in $links) {
                $lines.Add("| $(ConvertTo-MtAdConfigurationInventoryCell $link.Name) | $($link.Transport) | $(ConvertTo-MtAdConfigurationInventoryCell $link.Cost) | $(ConvertTo-MtAdConfigurationInventoryCell $link.Interval) | $(ConvertTo-MtAdConfigurationInventoryCell $link.Sites) | $(ConvertTo-MtAdConfigurationInventoryCell $link.DistinguishedName) |")
            }
        }
    }
    if ($lines.Count -eq 0) { throw 'Inventory report could not be generated.' }
    Add-MtTestResultDetail -Result ($lines -join "`n") -Investigate
    return $true
}
