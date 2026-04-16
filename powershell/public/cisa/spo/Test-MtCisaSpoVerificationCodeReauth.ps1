function Test-MtCisaSpoVerificationCodeReauth {
    <#
    .SYNOPSIS
    Checks state of verification code reauthentication for SharePoint Online

    .DESCRIPTION
    Reauthentication with verification code SHOULD be required after thirty days or less.

    .EXAMPLE
    Test-MtCisaSpoVerificationCodeReauth

    Returns true if verification code reauthentication is required within 30 days or less

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoVerificationCodeReauth
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection SharePoint)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSharePoint
        return $null
    }

    try {
        $spoTenant = Get-MtSpo

        # Only applicable when sharing allows external users: ExternalUserSharingOnly (1) or ExternalUserAndGuestSharing (2)
        if ($spoTenant.SharingCapability -notin @("ExternalUserSharingOnly", "ExternalUserAndGuestSharing")) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "External sharing does not allow new or anonymous guests. Verification code reauthentication is not applicable."
            return $null
        }

        # EmailAttestationRequired: $true = verification code required, $false = not required
        # EmailAttestationReAuthDays: number of days before reauthentication is required
        # CISA requires <= 30 days
        $testResult = $spoTenant.EmailAttestationRequired -eq $true -and $spoTenant.EmailAttestationReAuthDays -le 30

        if ($testResult) {
            $testResultMarkdown = "Well done. Verification code reauthentication is required every $($spoTenant.EmailAttestationReAuthDays) day(s)."
        } else {
            $testResultMarkdown = "Verification code reauthentication is not properly configured.`n`n* Email attestation required: ``$($spoTenant.EmailAttestationRequired)``  `n* Reauthentication days: ``$($spoTenant.EmailAttestationReAuthDays)``"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
