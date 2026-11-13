function Test-MtAdcsPublishedTemplatePrerequisites {
    [MaesterTest(
        Id = 'AD-CS-01',
        Title = 'Published AD CS templates should not expose dangerous enrollment prerequisites',
        Product = 'ad',
        Feature = 'certificate-services',
        Area = 'infrastructure',
        ResourceType = 'CertificateTemplate',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1649',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Configuration/*:ReadProperty'),
        Author = 'Mario Contestabile'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState -Categories @('Configuration')
    if ($null -eq $adState -or $null -eq $adState.Configuration) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $state = ConvertTo-MtAdcsEnrollmentPrerequisiteState -Configuration $adState.Configuration
    if (-not $state.EvidenceAvailable) {
        Add-MtTestResultDetail -Result 'Required AD CS publication or template evidence was unavailable.' -Investigate
        return $null
    }

    $candidates = @($state.Templates | Where-Object Disposition -in @('PotentiallyEligible','Eligible','Inconclusive'))
    $result = "| Template | Published | Authentication capable | Supplies subject | Manager approval | ACL evidence | Disposition |`n"
    $result += "| --- | --- | --- | --- | --- | --- | --- |`n"
    foreach ($candidate in $candidates) {
        $result += "| $($candidate.Name) | $($candidate.Published) | $($candidate.AuthenticationCapable) | $($candidate.EnrolleeSuppliesSubject) | $($candidate.ManagerApprovalRequired) | $($candidate.SecurityDescriptorAvailable) | $($candidate.Disposition) |`n"
    }

    if ($candidates.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No published certificate template matched the modeled dangerous enrollment prerequisites.'
        return $true
    }

    Add-MtTestResultDetail -Result "Published template candidates require authorization review. Configuration prerequisites do not prove exploitation.`n`n$result" -Investigate
    return $null
}