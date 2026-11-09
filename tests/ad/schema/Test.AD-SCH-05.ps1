function Test-MtAdLapsInstalledStatus {
    <#
    .SYNOPSIS
    Checks whether Windows or legacy Microsoft LAPS schema attributes are present.

    .DESCRIPTION
    This test inventories both complete LAPS schema pairs: Windows LAPS and legacy
    Microsoft LAPS. Either complete pair satisfies this schema-readiness assessment.
    Legacy artifacts remain visible even after migration. Schema presence alone does
    not prove deployment, permissions, policy, encryption or password rotation.

    .EXAMPLE
    Test-MtAdLapsInstalledStatus

    Returns $true when either complete LAPS schema pair is present.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdLapsInstalledStatus
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-SCH-05',
        Title = 'Windows or legacy Microsoft LAPS schema should be ready in Active Directory',
        Product = 'ad',
        Feature = 'schema',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.003', 'T1550.002'),
        Control = 'nist-800-53-r5:IA-5',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Schema/*:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdLapsInstalledStatus"

    $adState = Get-MtADDomainState -Categories @('Schema')
    if ($null -eq $adState) {
        throw 'Active Directory schema inventory was not returned.'
    }
    if ($null -eq $adState.SchemaObjects) { throw 'Active Directory schema objects were not returned.' }
    $names = @($adState.SchemaObjects | ForEach-Object { $_.LdapDisplayName })
    $passwordPresent = $names -contains 'msLAPS-Password'
    $expirationPresent = $names -contains 'msLAPS-PasswordExpirationTime'
    $legacyPresent = $names -contains 'ms-Mcs-AdmPwd'
    $legacyExpirationPresent = $names -contains 'ms-Mcs-AdmPwdExpirationTime'
    $windowsReady = $passwordPresent -and $expirationPresent
    $legacyReady = $legacyPresent -and $legacyExpirationPresent

    $result = "| Schema attribute | Present |`n| --- | --- |`n"
    $result += "| msLAPS-Password | $passwordPresent |`n"
    $result += "| msLAPS-PasswordExpirationTime | $expirationPresent |`n"
    $result += "| Legacy ms-Mcs-AdmPwd | $legacyPresent |`n"
    $result += "| Legacy ms-Mcs-AdmPwdExpirationTime | $legacyExpirationPresent |`n"
    $result += "| Windows LAPS schema pair complete | $windowsReady |`n"
    $result += "| Legacy Microsoft LAPS schema pair complete | $legacyReady |`n"
    if ($windowsReady -or $legacyReady) {
        Add-MtTestResultDetail -Result "Well done. At least one complete LAPS schema pair is present. Both variants are listed, including legacy artifacts. Validate policy, client configuration, access permissions and current per-device expiration data separately; schema readiness is not proof that passwords are managed or rotating.`n`n$result"
        return $true
    }

    Add-MtTestResultDetail -Result "Neither Windows LAPS nor legacy Microsoft LAPS has a complete schema pair. Verify the intended deployment and schema extension. Partial or absent schema attributes do not demonstrate readiness; this check does not read password values.`n`n$result"
    return $false
}
