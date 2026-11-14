function Test-MtAdNtAuthCertificatePath {
    <#
    .SYNOPSIS
    Reviews NTAuth CA certificate paths against the published AD CA inventory.
    .DESCRIPTION
    Uses custom root trust and offline chain validation for Microsoft and third-party CA certificates.
    Reports incomplete or invalid paths for investigation without asserting actual DC trust or authentication success.
    #>
    [MaesterTest(
        Id = 'AD-PKI-13',
        Title = 'NTAuth CA certificate paths should be verifiable using published AD CA certificates.',
        Product = 'ad',
        Feature = 'certificate-services',
        Area = 'authentication',
        ResourceType = 'CertificateAuthority',
        Severity = 'Info',
        Mitre = 'None',
        Control = 'nist-800-53-r5:SC-17',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:Configuration/*:ReadProperty',
        Lifecycle = 'Preview',
        Author = 'FiraSenax'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories Configuration
    $paths = @(Get-MtAdNtAuthCertificatePath -Configuration $state.Configuration)
    if ($paths.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable -SkippedCustomReason 'The collected NTAuth store contains no CA certificates.'
    }

    $unverified = @($paths | Where-Object { -not $_.Verified })
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('| NTAuth CA | Thumbprint | Published root | Path | Observation |')
    $lines.Add('| --- | --- | --- | --- | --- |')
    foreach ($path in $paths) {
        $observation = if ($path.Verified) { 'Verified against published AD roots' } else { $path.Issues -join ', ' }
        $cells = @($path.Subject, $path.Thumbprint, $path.RootSubject, ($path.Path.Subject -join ' → '), $observation) |
            ForEach-Object { ConvertTo-MtAdConfigurationInventoryCell $_ }
        $lines.Add('| ' + ($cells -join ' | ') + ' |')
    }
    $summary = if ($unverified.Count -gt 0) {
        "Review $($unverified.Count) NTAuth certificate path(s) that could not be verified using the published AD inventory."
    } else { 'Well done. All observed NTAuth CA certificate paths verified against the published AD roots.' }
    $result = $summary + "`n`nThis offline observation does not assess revocation, local DC trust, CA issuance policy or PKINIT authentication.`n`n" + ($lines -join "`n")
    Add-MtTestResultDetail -Result $result -Investigate:($unverified.Count -gt 0)
    return $unverified.Count -eq 0
}
