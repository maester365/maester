function Test-MtAdcsPublishedTemplatePrerequisite {
    <#
    .SYNOPSIS
    Reviews published AD CS templates for modeled unguarded authentication-enrollment prerequisites.
    .DESCRIPTION
    Correlates CA publication, authentication EKUs, subject supply, manager approval and authorized signatures.
    Missing evidence remains inconclusive. Available security descriptors do not establish effective enrollment rights.
    #>
    [MaesterTest(
        Id = 'AD-CS-01',
        Title = 'Published AD CS templates should not expose unguarded authentication enrollment prerequisites.',
        Product = 'ad',
        Feature = 'certificate-services',
        Area = 'authentication',
        ResourceType = 'CertificateAuthority',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1649',
        Control = 'nist-800-53-r5:IA-5',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:Configuration/*:ReadProperty',
        Lifecycle = 'Preview',
        Author = 'rolling-code',
        Contributor = 'FiraSenax'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState -Categories Configuration
    $state = ConvertTo-MtAdcsEnrollmentPrerequisiteState -Configuration $adState.Configuration
    if (-not $state.EvidenceAvailable) {
        Add-MtTestResultDetail -Investigate -Result 'AD CS publication or template inventory is unavailable or incomplete; the modeled prerequisites could not be assessed.'
        return $false
    }
    if ($state.PublishedTemplateCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotApplicable -SkippedCustomReason 'The completed AD CS inventory contains no published certificate templates.'
    }
    $candidates = @($state.Templates | Where-Object Disposition -IN 'PotentiallyEligible', 'Inconclusive')
    if ($candidates.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. Every published template has at least one known condition that disproves this modeled unguarded enrollment path. Other AD CS risks require separate assessment.'
        return $true
    }
    $cell = {
        param($Value)
        if ($null -eq $Value) { return 'Unknown' }
        Get-MtSafeMarkdown -Text ([Net.WebUtility]::HtmlEncode(([string]$Value -replace '[\r\n]+', ' ')))
    }
    $table = "| Template | Published by | Authentication capable | Supplies subject | Manager approval | Authorized signatures | ACL available | Disposition | Missing evidence |`n"
    $table += "| --- | --- | --- | --- | --- | --- | --- | --- | --- |`n"
    foreach ($candidate in $candidates) {
        $values = @($candidate.Name, ($candidate.PublishedBy -join ', '), $candidate.AuthenticationCapable,
            $candidate.EnrolleeSuppliesSubject, $candidate.ManagerApprovalRequired, $candidate.AuthorizedSignaturesRequired,
            $candidate.SecurityDescriptorAvailable, $candidate.Disposition, ($candidate.MissingEvidence -join ' '))
        $cells = @($values | ForEach-Object { & $cell $_ })
        $table += '| ' + ($cells -join ' | ') + " |`n"
    }
    Add-MtTestResultDetail -Investigate -Result "Review $($state.PotentiallyEligibleCount) template candidate(s) and $($state.InconclusiveCount) inconclusive template(s). Availability of an ACL is not proof of effective enrollment rights. No certificate enrollment or authentication was attempted.`n`n$table"
    return $false
}
