function Get-MtEmergencyAccessAccount {
    <#
    .SYNOPSIS
        Returns the emergency access (break-glass) accounts and groups configured in maester-config.json, resolved to directory object IDs.

    .DESCRIPTION
        Reads the EmergencyAccessAccounts global setting and resolves each entry - by object Id, or by
        UserPrincipalName / mail - to its directory object id and type (user or group). Returns objects
        with ObjectId, DisplayName, and Type. Returns nothing when no emergency access accounts are
        configured or none can be resolved.

    .EXAMPLE
        Get-MtEmergencyAccessAccount

        Returns the resolved emergency access accounts and groups.
    #>
    [CmdletBinding()]
    param ()

    $emergencyAccessAccounts = Get-MtMaesterConfigGlobalSetting -SettingName 'EmergencyAccessAccounts'
    if (-not $emergencyAccessAccounts) {
        return
    }

    $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $resolved = @()

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
                Write-Warning "Invalid identifier format for emergency access account: $identifier"
                continue
            }

            if ($object) {
                $resolved += [pscustomobject]@{
                    ObjectId    = $object.id
                    DisplayName = $object.displayName
                    Type        = $type
                }
            }
        } catch {
            Write-Warning "Could not resolve emergency access $type`: $identifier. $($_.Exception.Message)"
        }
    }

    return $resolved | Sort-Object Type, ObjectId -Unique
}
