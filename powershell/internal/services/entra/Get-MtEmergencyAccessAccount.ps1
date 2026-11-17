function Get-MtEmergencyAccessAccount {
    <#
    .SYNOPSIS
        Resolves emergency access (break-glass) accounts and groups to directory object IDs.

    .DESCRIPTION
        Resolves each entry of the EmergencyAccessAccounts setting - by object Id, or by
        UserPrincipalName / mail - to its directory object id and type (user or group). Returns objects
        with ObjectId, DisplayName, and Type. Returns nothing when no accounts are passed.

        A test receives the setting as a parameter, [MaesterParameter(Setting = 'EmergencyAccessAccounts')],
        and passes it here, so a test's own TestSettings row can override it.

    .EXAMPLE
        Get-MtEmergencyAccessAccount -Account $EmergencyAccessAccounts

        Returns the resolved emergency access accounts and groups.
    #>
    [CmdletBinding()]
    param (
        # The entries of the EmergencyAccessAccounts setting: objects with Id or UserPrincipalName, and Type.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [object[]] $Account = @()
    )

    $emergencyAccessAccounts = @($Account | Where-Object { $_ })
    if ($emergencyAccessAccounts.Count -eq 0) {
        return
    }

    $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $resolved = @()
    $resolutionFailures = @()

    foreach ($account in $emergencyAccessAccounts) {
        $identifier = if ($account.Id) { $account.Id } else { $account.UserPrincipalName }
        $type = if ($account.Type) { $account.Type.ToLower() } else { 'user' }
        if (-not $identifier) { continue }

        try {
            $object = $null
            if ($identifier -match $guidPattern) {
                $endpoint = if ($type -eq 'group') { "groups/$identifier" } else { "users/$identifier" }
                $object = Invoke-MtGraphRequest -RelativeUri $endpoint -Select id, displayName -ErrorAction Stop
            } elseif ($identifier -match '^[^@]+@[^@]+\.[^@]+$') {
                if ($type -eq 'group') {
                    $object = Invoke-MtGraphRequest -RelativeUri 'groups' -Filter "mail eq '$identifier' or mailNickname eq '$identifier'" -ErrorAction Stop | Select-Object -First 1
                } else {
                    $object = Invoke-MtGraphRequest -RelativeUri "users/$identifier" -Select id, displayName -ErrorAction Stop
                }
            } else {
                $resolutionFailures += "$type`: $identifier (invalid identifier format)"
                continue
            }

            if ($object) {
                $resolved += [pscustomobject]@{
                    ObjectId    = $object.id
                    DisplayName = $object.displayName
                    Type        = $type
                }
            } else {
                $resolutionFailures += "$type`: $identifier (not found)"
            }
        } catch {
            $resolutionFailures += "$type`: $identifier ($($_.Exception.Message))"
        }
    }

    # A configured break-glass account that cannot be resolved must not be silently dropped - the
    # consuming check would then verify only the accounts that happened to resolve (or skip entirely),
    # which can hide a real lock-out risk. Fail so the check reports an indeterminate result instead.
    if ($resolutionFailures.Count -gt 0) {
        throw "Could not resolve configured emergency access object(s): $($resolutionFailures -join '; ')"
    }

    return $resolved | Sort-Object Type, ObjectId -Unique
}
