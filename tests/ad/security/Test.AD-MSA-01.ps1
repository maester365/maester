function Test-MtAdManagedServiceAccountCount {
    <#
    .SYNOPSIS
    Counts managed service accounts (MSAs) in the domain.

    .DESCRIPTION
    Managed Service Accounts (MSAs) and Group Managed Service Accounts (gMSAs) provide
    automatic password management and simplified service principal name (SPN) management
    for services running on domain-joined computers. This test counts the number of
    sMSAs, gMSAs and delegated MSAs (dMSAs) in the domain. dMSA schema and
    setup support were introduced with Windows Server 2025; inventory presence
    alone does not demonstrate successful password management or migration.

    Security Benefits of MSAs:
    - Automatic password rotation (every 30 days for gMSAs)
    - Eliminates manual password management for service accounts
    - Cannot be used for interactive logons
    - Reduces risk of credential theft and reuse
    - Should be used instead of traditional service accounts where possible

    .EXAMPLE
    Test-MtAdManagedServiceAccountCount

    Returns $true if service account data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdManagedServiceAccountCount
    #>
    [MaesterTest(
        Id = 'AD-MSA-01',
        Title = 'Managed service account count should be investigated',
        Product = 'ad',
        Feature = 'account-security',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:msDS-ManagedServiceAccount:ReadProperty', 'ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount:ReadProperty', 'ActiveDirectory:Ldap:msDS-DelegatedManagedServiceAccount:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdManagedServiceAccountCount"
    $adState = Get-MtADDomainState -Categories @('ServiceAccounts')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState) {
        throw 'Active Directory service account inventory was not returned.'
    }
    Write-Verbose "Filtering/counting managed service account count"

    $serviceAccounts = $adState.ServiceAccounts

    if ($null -eq $serviceAccounts) { throw 'Active Directory service accounts were not returned.' }
    $msaCount = @($serviceAccounts).Count

    # Distinguish between MSA and gMSA if possible
    $delegatedMSAs = @($serviceAccounts | Where-Object { $_.ObjectClass -contains 'msDS-DelegatedManagedServiceAccount' })
    $groupMSAs = @($serviceAccounts | Where-Object { $_.ObjectClass -contains 'msDS-GroupManagedServiceAccount' -and $_.ObjectClass -notcontains 'msDS-DelegatedManagedServiceAccount' })
    $standaloneMSAs = @($serviceAccounts | Where-Object { $_.ObjectClass -contains 'msDS-ManagedServiceAccount' -and $_.ObjectClass -notcontains 'msDS-GroupManagedServiceAccount' -and $_.ObjectClass -notcontains 'msDS-DelegatedManagedServiceAccount' })

    $gmsaCount = ($groupMSAs | Measure-Object).Count
    $standaloneCount = ($standaloneMSAs | Measure-Object).Count
    $delegatedCount = $delegatedMSAs.Count
    $undeterminedCount = $msaCount - $gmsaCount - $standaloneCount - $delegatedCount

    $testResult = $null -ne $adState.ServiceAccounts

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Managed Service Accounts | $msaCount |" + "`n"
    $result += "| Group Managed Service Accounts (gMSA) | $gmsaCount |" + "`n"
    $result += "| Standalone Managed Service Accounts | $standaloneCount |" + "`n"
    $result += "| Delegated Managed Service Accounts (dMSA) | $delegatedCount |" + "`n"
    if ($undeterminedCount -gt 0) {
        $result += "| Undetermined Type | $undeterminedCount |" + "`n"
    }

    if ($msaCount -gt 0) {
        $result += "`n**Managed Service Accounts:**" + "`n" + "`n"
        $result += "| Account Name | Type | Delegated MSA state |" + "`n"
        $result += "| --- | --- | --- |" + "`n"

        foreach ($msa in $serviceAccounts | Select-Object -First 20) {
            $type = if ($delegatedMSAs -contains $msa) { 'dMSA' } elseif ($groupMSAs -contains $msa) { 'gMSA' } elseif ($standaloneMSAs -contains $msa) { 'sMSA' } else { 'Unknown' }
            $state = if ($type -eq 'dMSA' -and $null -ne $msa.DelegatedMsaState) { $msa.DelegatedMsaState } else { 'N/A' }
            $result += "| $($msa.Name) | $type | $state |" + "`n"
        }

        if ($msaCount -gt 20) {
            $result += "| ... and $($msaCount - 20) more | | |" + "`n"
        }
    } else {
        $result += "`n**No managed service accounts found.**" + "`n" + "`n"
        $result += "Consider using gMSAs for services instead of traditional service accounts for improved security." + "`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Managed service accounts provide automatic password management and improved security for service accounts.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdManagedServiceAccountCount"

    return $testResult
}
