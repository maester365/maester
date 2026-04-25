function Test-MtAdKrbtgtNonStandardUacCount {
    <#
    .SYNOPSIS
    Checks if the KRBTGT account has non-standard User Account Control (UAC) settings.

    .DESCRIPTION
    The KRBTGT account should have a standard UAC value of 514 (disabled, normal account).
    This test checks if the KRBTGT account has any non-standard UAC settings that could
    indicate misconfiguration or potential security issues.

    Standard KRBTGT UAC:
    - ACCOUNTDISABLE (0x0002) - Account should be disabled
    - NORMAL_ACCOUNT (0x0200) - Normal user account
    - Expected combined value: 514 (0x0202)

    Security Concern:
    - KRBTGT should NEVER be enabled
    - Non-standard UAC may indicate tampering or misconfiguration
    - Additional flags like DONT_EXPIRE_PASSWORD are sometimes set but should be reviewed

    .EXAMPLE
    Test-MtAdKrbtgtNonStandardUacCount

    Returns $true if KRBTGT has standard UAC settings.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdKrbtgtNonStandardUacCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $users = $adState.Users
    $krbtgt = $users | Where-Object { $_.SamAccountName -eq 'krbtgt' } | Select-Object -First 1

    if ($null -eq $krbtgt) {
        Add-MtTestResultDetail -Result "KRBTGT account not found in Active Directory."
        return $false
    }

    # Standard KRBTGT UAC is 514 (disabled normal account)
    # 0x0200 (512) = NORMAL_ACCOUNT
    # 0x0002 (2) = ACCOUNTDISABLE
    # Combined: 514
    $standardUac = 514
    $actualUac = $krbtgt.userAccountControl

    $isStandard = ($actualUac -eq $standardUac)
    $testResult = $isStandard

    # Decode UAC flags for display
    $uacFlags = @()
    if ($actualUac -band 0x0001) { $uacFlags += "SCRIPT" }
    if ($actualUac -band 0x0002) { $uacFlags += "ACCOUNTDISABLE" }
    if ($actualUac -band 0x0008) { $uacFlags += "HOMEDIR_REQUIRED" }
    if ($actualUac -band 0x0010) { $uacFlags += "LOCKOUT" }
    if ($actualUac -band 0x0020) { $uacFlags += "PASSWD_NOTREQD" }
    if ($actualUac -band 0x0040) { $uacFlags += "PASSWD_CANT_CHANGE" }
    if ($actualUac -band 0x0080) { $uacFlags += "ENCRYPTED_TEXT_PWD_ALLOWED" }
    if ($actualUac -band 0x0100) { $uacFlags += "TEMP_DUPLICATE_ACCOUNT" }
    if ($actualUac -band 0x0200) { $uacFlags += "NORMAL_ACCOUNT" }
    if ($actualUac -band 0x0800) { $uacFlags += "INTERDOMAIN_TRUST_ACCOUNT" }
    if ($actualUac -band 0x1000) { $uacFlags += "WORKSTATION_TRUST_ACCOUNT" }
    if ($actualUac -band 0x2000) { $uacFlags += "SERVER_TRUST_ACCOUNT" }
    if ($actualUac -band 0x10000) { $uacFlags += "DONT_EXPIRE_PASSWORD" }
    if ($actualUac -band 0x20000) { $uacFlags += "MNS_LOGON_ACCOUNT" }
    if ($actualUac -band 0x40000) { $uacFlags += "SMARTCARD_REQUIRED" }
    if ($actualUac -band 0x80000) { $uacFlags += "TRUSTED_FOR_DELEGATION" }
    if ($actualUac -band 0x100000) { $uacFlags += "NOT_DELEGATED" }
    if ($actualUac -band 0x200000) { $uacFlags += "USE_DES_KEY_ONLY" }
    if ($actualUac -band 0x400000) { $uacFlags += "DONT_REQ_PREAUTH" }
    if ($actualUac -band 0x800000) { $uacFlags += "PASSWORD_EXPIRED" }
    if ($actualUac -band 0x1000000) { $uacFlags += "TRUSTED_TO_AUTH_FOR_DELEGATION" }
    if ($actualUac -band 0x04000000) { $uacFlags += "PARTIAL_SECRETS_ACCOUNT" }

    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Account Name | $($krbtgt.SamAccountName) |`n"
    $result += "| Current UAC Value | $actualUac |`n"
    $result += "| Standard UAC Value | $standardUac |`n"
    $result += "| UAC Is Standard | $(if ($isStandard) { 'Yes' } else { 'No - REVIEW REQUIRED' }) |`n"
    $result += "| UAC Flags | $($uacFlags -join ', ') |`n"

    $testResultMarkdown = "KRBTGT account UAC settings analyzed. Standard UAC should be 514 (disabled normal account).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
