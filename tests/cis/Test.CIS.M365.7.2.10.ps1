function Test-MtCisSpoGuestReauthentication {
    <#
    .SYNOPSIS
        Ensure reauthentication with verification code is restricted

    .DESCRIPTION
        Checks that guests who sign in with a one-time verification code must sign in again within 15 days
        or fewer.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.10, L1)

    .EXAMPLE
        Test-MtCisSpoGuestReauthentication

        Returns true if guests using a verification code must reauthenticate every 15 days or less.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoGuestReauthentication
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.10',
        Title = 'Ensure reauthentication with verification code is restricted',
        Product = 'sharepoint',
        Feature = 'external-sharing',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('cis-m365:7.2.10', 'nist-800-53-r5:IA-5'),
        Service = 'SharePointOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisSpoGuestReauthentication: Checking the verification code settings'
    $spoTenant = Get-MtSpo
    $attestationRequired = $spoTenant.EmailAttestationRequired
    $reauthDays = $spoTenant.EmailAttestationReAuthDays
    $testResult = ($attestationRequired -eq $true) -and ($null -ne $reauthDays) -and ($reauthDays -le 15)

    $displayRequired = if ($null -eq $attestationRequired) { 'Not found' } else { $attestationRequired }
    $displayDays = if ($null -eq $reauthDays) { 'Not found' } else { $reauthDays }
    $resultMarkdown = if ($testResult) {
        "Well done. Guests using a verification code must reauthenticate within 15 days or less.`n`n"
    } elseif ($null -eq $attestationRequired -or $null -eq $reauthDays) {
        "The verification code settings could not be read from SharePoint Online.`n`n"
    } else {
        "Guests using a verification code are not required to reauthenticate within 15 days.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| EmailAttestationRequired | $displayRequired | $(if ($attestationRequired -eq $true) { 'Pass' } else { 'Fail' }) |`n"
    $resultMarkdown += "| EmailAttestationReAuthDays | $displayDays | $(if ($null -ne $reauthDays -and $reauthDays -le 15) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
