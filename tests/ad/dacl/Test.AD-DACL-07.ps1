function Test-MtAdDaclDistinctIdentityCount {
    <#
    .SYNOPSIS
    Counts distinct identities and reports ACE distribution by identity.

    .DESCRIPTION
    This test retrieves cached DACL entry data from Active Directory and counts the
    number of unique identities that appear in access control entries. Reviewing the
    number of distinct identities helps identify how broadly permissions are delegated
    across directory objects.

    .EXAMPLE
    Test-MtAdDaclDistinctIdentityCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclDistinctIdentityCount
    #>
    [MaesterTest(
        Id = 'AD-DACL-07',
        Title = 'DACL identity counts and ACE distribution should be investigated',
        Product = 'ad',
        Feature = 'permissions',
        Area = 'access-control',
        ResourceType = 'Permission',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Platform = 'Windows',
        Permission = ('ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl'),
        LongRunning,
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclDistinctIdentityCount"
    if (-not (Test-MtAdDaclPlatformSupported)) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $adState = Get-MtADDomainState -Categories @('DaclEntries')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState -or $null -eq $adState.DaclEntries) {
        throw 'DACL data is unavailable.'
    }
    Write-Verbose "Filtering/counting dacl distinct identity count"

    $daclEntries = @($adState.DaclEntries | Where-Object { $null -ne $_ })
    if ($daclEntries.Count -eq 0) {
        throw 'No DACL entries were collected; cannot assess identity distribution.'
    }
    if (@($daclEntries | Where-Object { [string]::IsNullOrWhiteSpace($_.ObjectDN) -or [string]::IsNullOrWhiteSpace($_.AccessControlType) }).Count -gt 0) {
        throw 'DACL entries are missing object names or access control types.'
    }
    $totalAceCount = ($daclEntries | Measure-Object).Count
    $distinctIdentityReferences = @(
        $daclEntries |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } |
            Select-Object -ExpandProperty IdentityReference -Unique
    )
    $distinctIdentityCount = ($distinctIdentityReferences | Measure-Object).Count
    $distinctObjectCount = @(
        $daclEntries |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
            Select-Object -ExpandProperty ObjectDN -Unique
    ).Count

    $largestIdentityGroup = $daclEntries |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } |
        Group-Object IdentityReference |
        Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
        Select-Object -First 1

    $testResult = $true

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total DACL ACEs | $totalAceCount |" + "`n"
    $result += "| Distinct identities | $distinctIdentityCount |" + "`n"
    $result += "| Distinct objects represented | $distinctObjectCount |" + "`n"

    if ($null -ne $largestIdentityGroup) {
        $largestIdentityName = [string]$largestIdentityGroup.Name
        $largestIdentityName = $largestIdentityName -replace '\|', '\\&#124;'
        $result += "| Identity with most ACEs | $largestIdentityName |" + "`n"
        $result += "| ACEs for most represented identity | $($largestIdentityGroup.Count) |" + "`n"
    }
    $result += "`n| Identity Reference | ACE Count | Distinct Objects | Allow ACEs | Deny ACEs |`n| --- | --- | --- | --- | --- |`n"
    foreach ($group in @($daclEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } | Group-Object IdentityReference | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name)) {
        $identity = ([string]$group.Name) -replace '\|', '&#124;'
        $objects = @($group.Group | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } | Select-Object -ExpandProperty ObjectDN -Unique).Count
        $allows = @($group.Group | Where-Object { $_.AccessControlType -eq 'Allow' }).Count
        $denies = @($group.Group | Where-Object { $_.AccessControlType -eq 'Deny' }).Count
        $result += "| $identity | $($group.Count) | $objects | $allows | $denies |`n"
    }
    if ($distinctIdentityCount -eq 0) {
        $result += "| No identities found | 0 | 0 | 0 | 0 |`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "This informational test summarizes how many unique identities are present across collected DACL ACEs.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdDaclDistinctIdentityCount"
    return $testResult
}
