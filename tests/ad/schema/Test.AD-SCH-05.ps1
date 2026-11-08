function Test-MtAdLapsInstalledStatus {
    <#
    .SYNOPSIS
    Checks whether Windows LAPS schema attributes are present in Active Directory.

    .DESCRIPTION
    This test checks for both msLAPS-Password and msLAPS-PasswordExpirationTime schema
    attributes. Legacy LAPS ms-Mcs-AdmPwd alone does not demonstrate Windows LAPS readiness.
    Schema presence does not prove deployment, permissions, policy or rotation.

    .EXAMPLE
    Test-MtAdLapsInstalledStatus

    Returns $true when both Windows LAPS schema attributes are present.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdLapsInstalledStatus
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-SCH-05',
        Title = 'Windows LAPS schema should be ready in Active Directory',
        Product = 'ad',
        Feature = 'schema',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.003', 'T1550.002'),
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
    if ($null -eq $adState.WindowsLapsInstalled) { throw 'Windows LAPS schema readiness was not returned.' }
    $names = @($adState.SchemaObjects | ForEach-Object { $_.LdapDisplayName })
    $passwordPresent = $names -contains 'msLAPS-Password'
    $expirationPresent = $names -contains 'msLAPS-PasswordExpirationTime'
    $legacyPresent = $names -contains 'ms-Mcs-AdmPwd'

    $result = "| Schema attribute | Present |`n| --- | --- |`n"
    $result += "| msLAPS-Password | $passwordPresent |`n"
    $result += "| msLAPS-PasswordExpirationTime | $expirationPresent |`n"
    $result += "| Legacy ms-Mcs-AdmPwd | $legacyPresent |"
    if ($adState.WindowsLapsInstalled -eq $true) {
        Add-MtTestResultDetail -Result "Well done. Both Windows LAPS schema attributes are present. This does not establish that password management is enabled or rotating.`n`n$result"
        return $true
    }

    Add-MtTestResultDetail -Result "Windows LAPS schema readiness could not be established: one or both required attributes are absent. Legacy LAPS presence alone is insufficient. Verify schema deployment; this check does not read password values.`n`n$result"
    return $false
}
