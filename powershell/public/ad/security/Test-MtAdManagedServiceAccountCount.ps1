function Test-MtAdManagedServiceAccountCount {
    <#
    .SYNOPSIS
    Counts managed service accounts (MSAs) in the domain.

    .DESCRIPTION
    Managed Service Accounts (MSAs) and Group Managed Service Accounts (gMSAs) provide
    automatic password management and simplified service principal name (SPN) management
    for services running on domain-joined computers. This test counts the number of
    MSAs and gMSAs in the domain.

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
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdManagedServiceAccountCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting managed service account count"

    $serviceAccounts = $adState.ServiceAccounts

    $msaCount = ($serviceAccounts | Measure-Object).Count

    # Distinguish between MSA and gMSA if possible
    $groupMSAs = $serviceAccounts | Where-Object { $_.ObjectClass -contains 'msDS-GroupManagedServiceAccount' -or $_.ServiceAccountType -eq 'GroupManagedServiceAccount' }
    $standaloneMSAs = $serviceAccounts | Where-Object { $_.ObjectClass -contains 'msDS-ManagedServiceAccount' -or $_.ServiceAccountType -eq 'ManagedServiceAccount' }

    $gmsaCount = ($groupMSAs | Measure-Object).Count
    $standaloneCount = ($standaloneMSAs | Measure-Object).Count
    $undeterminedCount = $msaCount - $gmsaCount - $standaloneCount

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Managed Service Accounts | $msaCount |`n"
    $result += "| Group Managed Service Accounts (gMSA) | $gmsaCount |`n"
    $result += "| Standalone Managed Service Accounts | $standaloneCount |`n"
    if ($undeterminedCount -gt 0) {
        $result += "| Undetermined Type | $undeterminedCount |`n"
    }

    if ($msaCount -gt 0) {
        $result += "`n**Managed Service Accounts:**`n`n"
        $result += "| Account Name | Type | Enabled |`n"
        $result += "| --- | --- | --- |`n"

        foreach ($msa in $serviceAccounts | Select-Object -First 20) {
            $type = if ($groupMSAs -contains $msa) { 'gMSA' } elseif ($standaloneMSAs -contains $msa) { 'MSA' } else { 'Unknown' }
            $enabled = if ($null -ne $msa.Enabled) { $msa.Enabled } else { 'N/A' }
            $result += "| $($msa.Name) | $type | $enabled |`n"
        }

        if ($msaCount -gt 20) {
            $result += "| ... and $($msaCount - 20) more | | |`n"
        }
    } else {
        $result += "`n**No managed service accounts found.**`n`n"
        $result += "Consider using gMSAs for services instead of traditional service accounts for improved security.`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Managed service accounts provide automatic password management and improved security for service accounts.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdManagedServiceAccountCount"

    return $testResult
}




