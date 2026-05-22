function Test-MtHasPermission {
    <#
    .SYNOPSIS
    Checks if the current session has the required permissions or roles.

    .PARAMETER TestId
    The ID of the test to check permissions for. Requirements are read from Maester config.

    .PARAMETER RequiredPermissions
    Optional hashtable or object of permissions to check against. Overrides config lookup.
    Example: @{ Graph = @('User.Read.All'); EntraRoles = @('Global Reader') }

    .DESCRIPTION
    For Graph scopes, all listed permissions are required (AND check), with Read permissions
    automatically being satisfied by their ReadWrite equivalents.
    For EntraRoles, ExchangeOnline, and Azure roles, only one of the listed roles is required (OR check).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$TestId,
        $RequiredPermissions
    )

    Write-Verbose "Checking permissions for TestId: $TestId"

    # 1. Check Global Bypass (CLI switch -SkipPermissionCheck)
    if ($__MtSession.SkipPermissionCheck) {
        Write-Verbose "Permission check skipped globally via CLI."
        return $true
    }

    # 2. Check Global Bypass (Config GlobalSettings.SkipPermissionCheck)
    if ($__MtSession.MaesterConfig.GlobalSettings.SkipPermissionCheck) {
        Write-Verbose "Permission check skipped globally via Maester config."
        return $true
    }

    if (-not $RequiredPermissions -and [string]::IsNullOrEmpty($TestId)) {
        return $true
    }

    $testSetting = $null
    if (-not $RequiredPermissions -and ![string]::IsNullOrEmpty($TestId)) {
        $testSetting = Get-MtMaesterConfigTestSetting -TestId $TestId
        if ($null -ne $testSetting) {
            # 3. Check Per-Test Bypass (Config TestSettings[].SkipPermissionCheck)
            if ($testSetting.SkipPermissionCheck) {
                Write-Verbose "Permission check skipped for test $TestId via Maester config."
                return $true
            }
            $RequiredPermissions = $testSetting.RequiredPermissions
        }
    }

    if ($null -eq $RequiredPermissions) {
        Write-Verbose "No permissions required for $TestId"
        return $true
    }

    # Handle PSCustomObject (from JSON) or Hashtable
    $serviceKeys = @()
    try {
        if ($RequiredPermissions -is [hashtable] -or $RequiredPermissions -is [System.Collections.IDictionary]) {
            $serviceKeys = $RequiredPermissions.Keys
        } elseif ($null -ne $RequiredPermissions.PSObject -and $null -ne $RequiredPermissions.PSObject.Properties) {
            $serviceKeys = $RequiredPermissions.PSObject.Properties.Name
        }
    } catch {
        Write-Verbose "Failed to extract service keys: $_"
    }

    if ($null -eq $serviceKeys -or $serviceKeys.Count -eq 0) {
        Write-Verbose "No service-specific permissions found in requirement."
        return $true
    }

    $available = Get-MtAuthorization

    foreach ($service in $serviceKeys) {
        $required = @()
        if ($RequiredPermissions -is [hashtable] -or $RequiredPermissions -is [System.Collections.IDictionary]) {
            $required = @($RequiredPermissions[$service])
        } else {
            $required = @($RequiredPermissions.$service)
        }

        # Filter out null/empty requirements
        $required = $required | Where-Object { $_ }
        if ($required.Count -eq 0) { continue }

        $owned = @($available[$service])
        if ($null -eq $owned) { $owned = @() }

        Write-Verbose "Checking ${service}: Required: $($required -join ', '), Owned: $($owned.Count) items"

        if ($service -eq 'Graph') {
            # AND check for Graph scopes
            foreach ($perm in $required) {
                $found = $false
                foreach ($o in $owned) {
                    if ($o -ieq $perm) {
                        $found = $true
                        break
                    }
                }

                if (-not $found -and $perm -match '\.Read\.') {
                    $rwPerm = $perm -replace '\.Read\.', '.ReadWrite.'
                    foreach ($o in $owned) {
                        if ($o -ieq $rwPerm) {
                            $found = $true
                            break
                        }
                    }
                }

                if (-not $found) {
                    Write-Verbose "Missing required ${service} scope: $perm"
                    return $false
                }
            }
        } else {
            # OR check for Roles (at least one must match)
            $foundAny = $false
            foreach ($perm in $required) {
                foreach ($o in $owned) {
                    if ($o -ieq $perm) {
                        $foundAny = $true
                        break
                    }
                }
                if ($foundAny) { break }
            }

            if (-not $foundAny) {
                Write-Verbose "Missing at least one required ${service} role: $($required -join ', ')"
                return $false
            }
        }
    }

    return $true
}
