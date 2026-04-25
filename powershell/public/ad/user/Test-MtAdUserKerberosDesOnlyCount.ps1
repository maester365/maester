function Test-MtAdUserKerberosDesOnlyCount {
    <#
    .SYNOPSIS
    Counts user accounts configured to use DES-only Kerberos encryption.

    .DESCRIPTION
    This test identifies user accounts that still rely on DES for Kerberos. DES is
    deprecated and cryptographically weak, so these accounts should be remediated and
    moved to stronger encryption types where possible.

    .EXAMPLE
    Test-MtAdUserKerberosDesOnlyCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserKerberosDesOnlyCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }

    $users = @($adState.Users)
    $desOnlyUsers = @($users | Where-Object {
            ($_.PSObject.Properties['KerberosEncryptionType'] -and (($_.KerberosEncryptionType | Out-String) -match 'DES')) -or
            ($_.PSObject.Properties['UseDESKeyOnly'] -and $_.UseDESKeyOnly -eq $true)
        })

    $desOnlyCount = $desOnlyUsers.Count
    $totalCount = $users.Count
    $enabledCount = @($users | Where-Object { $_.Enabled -eq $true }).Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($desOnlyCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Enabled Users | $enabledCount |`n"
        $result += "| Users with DES-Only Kerberos | $desOnlyCount |`n"
        $result += "| DES-Only Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $desOnlyCount out of $totalCount users ($percentage%) are configured to use DES-only Kerberos encryption.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
