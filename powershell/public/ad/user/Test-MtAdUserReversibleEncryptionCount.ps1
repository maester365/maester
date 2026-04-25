function Test-MtAdUserReversibleEncryptionCount {
    <#
    .SYNOPSIS
    Counts user accounts configured to allow reversible password encryption.

    .DESCRIPTION
    This test identifies user accounts where password storage may allow reversible
    encryption semantics. The test checks explicit reversible encryption-style flags if
    available and falls back to the userAccountControl bit commonly associated with this
    risky legacy configuration.

    .EXAMPLE
    Test-MtAdUserReversibleEncryptionCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserReversibleEncryptionCount
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
    $reversibleEncryptionUsers = @($users | Where-Object {
            $hasExplicitFlag = ($_.PSObject.Properties['ReversibleEncryption'] -and $_.ReversibleEncryption -eq $true) -or
            ($_.PSObject.Properties['AllowReversiblePasswordEncryption'] -and $_.AllowReversiblePasswordEncryption -eq $true)

            $hasUserAccountControlFlag = $_.PSObject.Properties['userAccountControl'] -and
            ($_.userAccountControl -band 0x80)

            $hasExplicitFlag -or $hasUserAccountControlFlag
        })

    $reversibleEncryptionCount = $reversibleEncryptionUsers.Count
    $totalCount = $users.Count
    $enabledCount = @($users | Where-Object { $_.Enabled -eq $true }).Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($reversibleEncryptionCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Enabled Users | $enabledCount |`n"
        $result += "| Users with Reversible Encryption | $reversibleEncryptionCount |`n"
        $result += "| Reversible Encryption Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $reversibleEncryptionCount out of $totalCount users ($percentage%) are configured for reversible password encryption behavior.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
