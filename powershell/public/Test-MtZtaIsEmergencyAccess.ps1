function Test-MtZtaIsEmergencyAccess {
    <#
    .SYNOPSIS
        Returns $true when the supplied principalId or UPN matches an entry in
        `$script:MtZtaContext.EmergencyAccessAccounts` (the operator's break-glass
        list, sourced from `GlobalSettings.EmergencyAccessAccounts` in maester-config.json).

    .DESCRIPTION
        Use from ZTA gap-fill tests that surface privileged identities (permanent role
        grants, stale users, single-factor users, etc.) so legitimate break-glass accounts
        are flagged as compliant-by-design rather than reported as findings.

        Match is permissive: either Id or UPN match counts. UPN comparison is
        case-insensitive (Entra UPNs are case-insensitive). Returns $false on any
        missing context or empty input.

        Companion to `Get-MtZta -Section EmergencyAccessAccounts` which returns the
        normalised array.

    .PARAMETER Id
        Object ID (GUID) of the principal under inspection. Matched against entries
        whose `Id` is populated.

    .PARAMETER UserPrincipalName
        UPN of the principal. Matched case-insensitively against entries whose
        `UserPrincipalName` is populated.

    .EXAMPLE
        if (Test-MtZtaIsEmergencyAccess -Id $r.principalId -UserPrincipalName $u.userPrincipalName) {
            # mark as break-glass in the report; don't include in finding count
        }

    .LINK
        https://maester.dev/docs/commands/Test-MtZtaIsEmergencyAccess

    .LINK
        https://maester.dev/docs/zero-trust-assessment
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Id,

        [Parameter(Mandatory = $false)]
        [string] $UserPrincipalName
    )

    if (-not $script:MtZtaContext) { return $false }
    if (-not $script:MtZtaContext.PSObject.Properties['EmergencyAccessAccounts']) { return $false }
    $known = @($script:MtZtaContext.EmergencyAccessAccounts)
    if ($known.Count -eq 0) { return $false }

    foreach ($e in $known) {
        if (-not $e) { continue }
        if ($Id -and $e.Id -and ($e.Id -eq $Id)) { return $true }
        if ($UserPrincipalName -and $e.UserPrincipalName -and ($e.UserPrincipalName -ieq $UserPrincipalName)) { return $true }
    }
    return $false
}
