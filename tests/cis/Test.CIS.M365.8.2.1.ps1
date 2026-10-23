function Test-MtCisTeamsExternalDomainsRestricted {
    <#
    .SYNOPSIS
        Ensure external domains are restricted in the Teams admin center

    .DESCRIPTION
        Checks that external access in Teams is turned off, or that federation with external domains is
        limited to a list of domains and does not allow all known domains.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.2.1, L2)

    .EXAMPLE
        Test-MtCisTeamsExternalDomainsRestricted

        Returns true if external domains are restricted in Teams.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsExternalDomainsRestricted
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.2.1',
        Title = 'Ensure external domains are restricted in the Teams admin center',
        Product = 'teams',
        Feature = 'external-access',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:8.2.1', 'nist-800-53-r5:AC-20'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsExternalDomainsRestricted: Checking the external access and federation settings'
    $externalAccessPolicy = Get-CsExternalAccessPolicy -Identity Global
    $federation = Get-CsTenantFederationConfiguration

    $enableFederation = $externalAccessPolicy.EnableFederationAccess
    $allowFederatedUsers = $federation.AllowFederatedUsers
    $allowedDomains = $federation.AllowedDomains

    # The Teams module returns AllowedDomains as a deserialized object. For "allow all known domains" the type name
    # and the string value contain AllowAllKnownDomains and the JSON is empty ({}). A list of domains has an
    # AllowedDomain property and a string value such as Domain=contoso.com.
    $allowAllKnownDomains = ($null -ne $allowedDomains) -and
        ("$($allowedDomains.PSObject.TypeNames -join ' ') $allowedDomains" -match 'AllowAllKnownDomains')

    $testResult = ($enableFederation -eq $false) -or
        ($allowFederatedUsers -eq $false) -or
        (($allowFederatedUsers -eq $true) -and ($null -ne $allowedDomains) -and (-not $allowAllKnownDomains))

    $displayFederation = if ($null -eq $enableFederation) { 'Not found' } else { $enableFederation }
    $displayAllowFederated = if ($null -eq $allowFederatedUsers) { 'Not found' } else { $allowFederatedUsers }
    $displayAllowAll = if ($allowAllKnownDomains) { 'Yes' } elseif ($null -eq $allowedDomains) { 'Not found' } else { 'No' }
    $resultMarkdown = if ($testResult) {
        "Well done. External domains are restricted in the Teams admin center.`n`n"
    } elseif ($null -eq $allowFederatedUsers -or $null -eq $allowedDomains) {
        "The Teams external access settings could not be read, so external domain restriction could not be confirmed.`n`n"
    } else {
        "External domains are not restricted. Federation allows all known domains.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| EnableFederationAccess (Global external access policy) | $displayFederation | $(if ($testResult) { 'Pass' } else { 'Fail' }) |`n"
    $resultMarkdown += "| AllowFederatedUsers | $displayAllowFederated | $(if ($testResult) { 'Pass' } else { 'Fail' }) |`n"
    $resultMarkdown += "| Allow all known domains | $displayAllowAll | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
