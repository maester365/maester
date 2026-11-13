function ConvertTo-MtAdcsEnrollmentPrerequisiteState {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [PSCustomObject] $Configuration
    )

    $clientAuthenticationOids = @(
        '1.3.6.1.5.5.7.3.2',
        '1.3.6.1.4.1.311.20.2.2',
        '1.3.6.1.5.2.3.4',
        '2.5.29.37.0'
    )
    $enrolleeSuppliesSubjectFlag = 0x00000001
    $pendAllRequestsFlag = 0x00000002

    if ($null -eq $Configuration) {
        return [PSCustomObject]@{
            EvidenceAvailable = $false
            Disposition = 'Inconclusive'
            Templates = @()
            EligibleCount = 0
            PotentiallyEligibleCount = 0
            InconclusiveCount = 0
        }
    }

    $enterpriseCas = @($Configuration.EnterpriseCAs)
    $templates = @($Configuration.CertificateTemplates)
    if ($null -eq $Configuration.EnterpriseCAs -or $null -eq $Configuration.CertificateTemplates) {
        return [PSCustomObject]@{
            EvidenceAvailable = $false
            Disposition = 'Inconclusive'
            Templates = @()
            EligibleCount = 0
            PotentiallyEligibleCount = 0
            InconclusiveCount = 0
        }
    }

    $publishedBy = @{}
    foreach ($ca in $enterpriseCas) {
        foreach ($templateName in @($ca.certificateTemplates)) {
            $name = [string](ConvertFrom-MtLdapValue $templateName)
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            if (-not $publishedBy.ContainsKey($name)) { $publishedBy[$name] = [System.Collections.Generic.List[string]]::new() }
            $caName = [string](ConvertFrom-MtLdapValue $ca.Name)
            if ([string]::IsNullOrWhiteSpace($caName)) { $caName = [string](ConvertFrom-MtLdapValue $ca.DistinguishedName) }
            $publishedBy[$name].Add($caName)
        }
    }

    $facts = foreach ($template in $templates) {
        $name = [string](ConvertFrom-MtLdapValue $template.Name)
        $ekuValues = @($template.'pKIExtendedKeyUsage' | ForEach-Object { [string](ConvertFrom-MtLdapValue $_) })
        $enrollmentFlagRaw = ConvertFrom-MtLdapValue $template.'msPKI-Enrollment-Flag'
        $nameFlagRaw = ConvertFrom-MtLdapValue $template.'msPKI-Certificate-Name-Flag'
        $enrollmentFlag = if ($null -eq $enrollmentFlagRaw) { $null } else { [int64]$enrollmentFlagRaw }
        $nameFlag = if ($null -eq $nameFlagRaw) { $null } else { [int64]$nameFlagRaw }
        $published = $publishedBy.ContainsKey($name)
        $authenticationCapable = @($ekuValues | Where-Object { $_ -in $clientAuthenticationOids }).Count -gt 0
        $suppliesSubject = $null -ne $nameFlag -and (($nameFlag -band $enrolleeSuppliesSubjectFlag) -ne 0)
        $managerApprovalRequired = $null -ne $enrollmentFlag -and (($enrollmentFlag -band $pendAllRequestsFlag) -ne 0)
        $securityDescriptorAvailable = $null -ne $template.nTSecurityDescriptor

        $disposition = if (-not $published -or -not $authenticationCapable -or -not $suppliesSubject -or $managerApprovalRequired) {
            'PrerequisitesNotSatisfied'
        }
        elseif (-not $securityDescriptorAvailable) {
            'Inconclusive'
        }
        else {
            'PotentiallyEligible'
        }

        [PSCustomObject]@{
            Name = $name
            Published = $published
            PublishedBy = if ($published) { @($publishedBy[$name]) } else { @() }
            AuthenticationCapable = $authenticationCapable
            EnrolleeSuppliesSubject = $suppliesSubject
            ManagerApprovalRequired = $managerApprovalRequired
            SecurityDescriptorAvailable = $securityDescriptorAvailable
            Disposition = $disposition
        }
    }

    $eligible = @($facts | Where-Object Disposition -eq 'Eligible').Count
    $potential = @($facts | Where-Object Disposition -eq 'PotentiallyEligible').Count
    $inconclusive = @($facts | Where-Object Disposition -eq 'Inconclusive').Count
    [PSCustomObject]@{
        EvidenceAvailable = $true
        Disposition = if ($potential -gt 0) { 'PotentiallyEligible' } elseif ($inconclusive -gt 0) { 'Inconclusive' } else { 'PrerequisitesNotSatisfied' }
        Templates = @($facts)
        EligibleCount = $eligible
        PotentiallyEligibleCount = $potential
        InconclusiveCount = $inconclusive
    }
}