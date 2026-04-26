function Test-MtAdDaclIdentityAceDistribution {
    <#
    .SYNOPSIS
    Returns the ACE distribution per identity in collected DACL data.

    .DESCRIPTION
    This test groups DACL access control entries by IdentityReference and reports how
    many ACEs are associated with each identity. The output helps highlight identities
    that appear frequently across directory object permissions and may warrant review.

    .EXAMPLE
    Test-MtAdDaclIdentityAceDistribution

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclIdentityAceDistribution
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclIdentityAceDistribution"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting dacl identity ace distribution"

    $daclEntries = @($adState.DaclEntries)
    $identityDistribution = @(
        $daclEntries |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } |
            Group-Object IdentityReference |
            Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            ForEach-Object {
                $entriesForIdentity = @($_.Group)
                [PSCustomObject]@{
                    IdentityReference = $_.Name
                    AceCount = $_.Count
                    DistinctObjectCount = @(
                        $entriesForIdentity |
                            Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
                            Select-Object -ExpandProperty ObjectDN -Unique
                    ).Count
                    AllowAceCount = @($entriesForIdentity | Where-Object { $_.AccessControlType -like 'AccessAllowed*' }).Count
                    DenyAceCount = @($entriesForIdentity | Where-Object { $_.AccessControlType -like 'AccessDenied*' }).Count
                }
            }
    )

    $testResult = $true

    $summary = "| Metric | Value |`n"
    $summary += "| --- | --- |`n"
    $summary += "| Total identities | $($identityDistribution.Count) |`n"
    $summary += "| Total DACL ACEs | $((@($daclEntries) | Measure-Object).Count) |`n"

    $table = "| IdentityReference | ACE Count | Distinct Objects | Allow ACEs | Deny ACEs |`n"
    $table += "| --- | --- | --- | --- | --- |`n"

    foreach ($identity in $identityDistribution) {
        $identityName = [string]$identity.IdentityReference
        $identityName = $identityName -replace '\|', '\\&#124;'
        $table += "| $identityName | $($identity.AceCount) | $($identity.DistinctObjectCount) | $($identity.AllowAceCount) | $($identity.DenyAceCount) |`n"
    }

    if ($identityDistribution.Count -eq 0) {
        $table += "| No identities found | 0 | 0 | 0 | 0 |`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "This informational test shows how DACL ACEs are distributed across identities.`n`n$summary`n$table"

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdDaclIdentityAceDistribution"
    return $testResult
}


