function ConvertTo-MtAdcsEnrollmentPrerequisiteState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)] [AllowNull()] [PSCustomObject] $Configuration
    )

    # Preserve the difference between an uncollected property and an observed empty value.
    $readField = {
        param($Item, [string] $Name)
        $present = $false
        $value = $null
        if ($Item -is [Collections.IDictionary]) {
            $present = $Item.Contains($Name)
            if ($present) { $value = $Item[$Name] }
        } elseif ($null -ne $Item) {
            $property = $Item.PSObject.Properties[$Name]
            $present = $null -ne $property
            if ($present) { $value = $property.Value }
        }
        [pscustomobject]@{ Present = $present; Value = $value }
    }
    $readNumber = {
        param($Field)
        $value = if ($Field.Present) { ConvertFrom-MtLdapValue -Value $Field.Value } else { $null }
        $number = 0L
        $known = $null -ne $value -and $value -isnot [bool] -and
            [long]::TryParse([string]$value, [ref]$number) -and $number -ge [int]::MinValue -and $number -le [uint32]::MaxValue
        [pscustomobject]@{ Known = $known; Value = if ($known) { $number } else { $null } }
    }
    $unavailable = [pscustomobject]@{
        EvidenceAvailable = $false; Disposition = 'Inconclusive'; Templates = @()
        PublishedTemplateCount = 0; PotentiallyEligibleCount = 0; InconclusiveCount = 0
        Reason = 'AD CS publication or template inventory is unavailable or incomplete.'
    }
    $caField = & $readField $Configuration 'EnterpriseCAs'
    $templateField = & $readField $Configuration 'CertificateTemplates'
    if ($null -eq $Configuration -or $null -eq $caField.Value -or $null -eq $templateField.Value) { return $unavailable }

    $publishedBy = @{}
    foreach ($ca in @($caField.Value)) {
        $publication = & $readField $ca 'certificateTemplates'
        if (-not $publication.Present) { return $unavailable }
        $caName = [string](ConvertFrom-MtLdapValue -Value (& $readField $ca 'Name').Value)
        if ([string]::IsNullOrWhiteSpace($caName)) { $caName = [string](ConvertFrom-MtLdapValue -Value (& $readField $ca 'DistinguishedName').Value) }
        foreach ($reference in @($publication.Value)) {
            $name = [string](ConvertFrom-MtLdapValue -Value $reference)
            if ([string]::IsNullOrWhiteSpace($name)) { return $unavailable }
            if (-not $publishedBy.ContainsKey($name)) { $publishedBy[$name] = [Collections.Generic.List[string]]::new() }
            $publishedBy[$name].Add($caName)
        }
    }
    $templatesByName = @{}
    foreach ($template in @($templateField.Value)) {
        $name = [string](ConvertFrom-MtLdapValue -Value (& $readField $template 'Name').Value)
        if ([string]::IsNullOrWhiteSpace($name)) { return $unavailable }
        if (-not $templatesByName.ContainsKey($name)) { $templatesByName[$name] = [Collections.Generic.List[object]]::new() }
        $templatesByName[$name].Add($template)
    }

    $authenticationOids = @('1.3.6.1.5.5.7.3.2', '1.3.6.1.4.1.311.20.2.2', '1.3.6.1.5.2.3.4', '2.5.29.37.0')
    $names = @(@($publishedBy.Keys) + @($templatesByName.Keys) | Sort-Object -Unique)
    $facts = @(foreach ($name in $names) {
        $published = $publishedBy.ContainsKey($name)
        $resolvedTemplates = if ($templatesByName.ContainsKey($name)) { $templatesByName[$name] } else { @() }
        $template = if ($resolvedTemplates.Count -eq 1) { $resolvedTemplates[0] } else { $null }
        $missing = [Collections.Generic.List[string]]::new()
        if ($resolvedTemplates.Count -ne 1) { $missing.Add('Published template could not be resolved uniquely.') }

        $ekuField = & $readField $template 'pKIExtendedKeyUsage'
        $eku = @(foreach ($value in @($ekuField.Value)) { if ($null -ne $value) { [string](ConvertFrom-MtLdapValue -Value $value) } })
        $malformedEku = @($eku | Where-Object { $_ -notmatch '^[0-2]\.\d+(?:\.\d+)*$' }).Count -gt 0
        $authenticationCapable = if (-not $ekuField.Present -or $malformedEku) { $null } else {
            $eku.Count -eq 0 -or @($eku | Where-Object { $_ -in $authenticationOids }).Count -gt 0
        }
        if ($null -eq $authenticationCapable) { $missing.Add('Authentication EKU evidence is unavailable or malformed.') }
        $nameFlag = & $readNumber (& $readField $template 'msPKI-Certificate-Name-Flag')
        $enrollmentFlag = & $readNumber (& $readField $template 'msPKI-Enrollment-Flag')
        $signatures = & $readNumber (& $readField $template 'msPKI-RA-Signature')
        if ($signatures.Known -and ($signatures.Value -lt 0 -or $signatures.Value -gt [int]::MaxValue)) { $signatures.Known = $false; $signatures.Value = $null }
        $suppliesSubject = if ($nameFlag.Known) { ($nameFlag.Value -band 1) -ne 0 } else { $null }
        $approvalRequired = if ($enrollmentFlag.Known) { ($enrollmentFlag.Value -band 2) -ne 0 } else { $null }
        if (-not $nameFlag.Known) { $missing.Add('Subject-supply flag is unavailable or malformed.') }
        if (-not $enrollmentFlag.Known) { $missing.Add('Enrollment flag is unavailable or malformed.') }
        if (-not $signatures.Known) { $missing.Add('Authorized-signature count is unavailable or malformed.') }
        $descriptor = (& $readField $template 'nTSecurityDescriptor').Value
        $descriptorAvailable = $null -ne $descriptor -and @($descriptor).Count -gt 0
        if (-not $descriptorAvailable) { $missing.Add('Security descriptor is unavailable; authorization is unresolved.') }

        # A known gate disproves this modeled path. Unknown evidence alone never disproves a prerequisite.
        $disposition = if (-not $published -or $authenticationCapable -eq $false -or $suppliesSubject -eq $false -or
            $approvalRequired -eq $true -or ($signatures.Known -and $signatures.Value -gt 0)) {
            'PrerequisitesNotSatisfied'
        } elseif ($missing.Count -gt 0) { 'Inconclusive' } else { 'PotentiallyEligible' }
        [pscustomobject]@{
            Name = $name; Published = $published
            PublishedBy = if ($published) { @($publishedBy[$name].ToArray() | Sort-Object -Unique) } else { @() }
            AuthenticationCapable = $authenticationCapable; EnrolleeSuppliesSubject = $suppliesSubject
            ManagerApprovalRequired = $approvalRequired; AuthorizedSignaturesRequired = $signatures.Value
            SecurityDescriptorAvailable = $descriptorAvailable; Disposition = $disposition
            MissingEvidence = $missing.ToArray()
        }
    })
    $potential = @($facts | Where-Object Disposition -EQ PotentiallyEligible).Count
    $inconclusive = @($facts | Where-Object Disposition -EQ Inconclusive).Count
    [pscustomobject]@{
        EvidenceAvailable = $true
        Disposition = if ($inconclusive -gt 0) { 'Inconclusive' } elseif ($potential -gt 0) { 'PotentiallyEligible' } else { 'PrerequisitesNotSatisfied' }
        Templates = $facts; PublishedTemplateCount = $publishedBy.Count
        PotentiallyEligibleCount = $potential; InconclusiveCount = $inconclusive; Reason = $null
    }
}
