function Test-MtCisaSpoSharingAllowedDomain {
    <#
    .SYNOPSIS
    Checks state of SharePoint Online sharing

    .DESCRIPTION
    External sharing SHALL be restricted to approved external domains and/or users in approved security groups per interagency collaboration needs.

    .EXAMPLE
    Test-MtCisaSpoSharingAllowedDomain

    Returns true if sharing uses restricted domains

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoSharingAllowedDomain
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

        if ($spoTenant.SharingCapability -eq "Disabled") {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "SharePoint Online external sharing is disabled."
            return $null
        }

        # SharingDomainRestrictionMode: 0 = None, 1 = AllowList, 2 = BlockList
        $testResult = $spoTenant.SharingDomainRestrictionMode -eq 1

        if ($testResult) {
            $allowedDomains = $spoTenant.SharingAllowedDomainList -split ' ' | Where-Object { $_ -ne '' }
            $domainList = ($allowedDomains | ForEach-Object { "* $_" }) -join "`n"
            $testResultMarkdown = "Well done. Your tenant restricts SharePoint Online sharing to approved domains.`n`n$domainList"
        } else {
            $testResultMarkdown = "Your tenant does not restrict SharePoint Online sharing to approved domains.`n`n* Current restriction mode: ``$($spoTenant.SharingDomainRestrictionMode)``"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
