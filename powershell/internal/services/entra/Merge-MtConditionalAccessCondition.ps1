function Merge-MtConditionalAccessCondition {
    <#
    .SYNOPSIS
    Combines inherited and rule-specific Conditional Access conditions without overwriting exclusions.

    .DESCRIPTION
    Merges Graph condition dictionaries recursively and unions collection values. Null and empty optional
    values do not erase inherited targeting. Incompatible scalar values, including conflicting filter expressions,
    terminate the read: inventing a lossy effective policy could make an uncovered scenario pass a security check.
    Inputs are JSON-compatible copies owned by the policy adapter, not objects in the Graph session cache.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $Shared,
        [AllowNull()] [object] $Rule,
        [string] $PropertyPath = 'conditions'
    )

    if ($null -eq $Shared) { Write-Output -NoEnumerate -InputObject $Rule; return }
    if ($null -eq $Rule) { Write-Output -NoEnumerate -InputObject $Shared; return }

    if ($Shared -is [System.Collections.IDictionary] -and $Rule -is [System.Collections.IDictionary]) {
        # Guest type and tenant membership form a pair. Unioning both independently invents cross-products
        # (type A in tenant X plus type B in tenant Y must not become both types in both tenants).
        if ($PropertyPath -match '\.(includeGuestsOrExternalUsers|excludeGuestsOrExternalUsers)$') {
            $sharedTypes = @(([string]$Shared.guestOrExternalUserTypes -split ',') | Sort-Object -Unique) -join ','
            $ruleTypes = @(([string]$Rule.guestOrExternalUserTypes -split ',') | Sort-Object -Unique) -join ','
            # Tenant membership is a set, independent of member order, duplicate IDs or JSON key order.
            # Keep a missing scope distinct from both all and an empty enumerated scope.
            $tenantScopes = foreach ($condition in @($Shared, $Rule)) {
                if ($null -eq $condition.externalTenants) {
                    'absent'
                } else {
                    [ordered]@{
                        membershipKind = $condition.externalTenants.membershipKind
                        members = @($condition.externalTenants.members | Sort-Object -Unique)
                    } | ConvertTo-Json -Depth 100 -Compress
                }
            }
            if ($sharedTypes -ne $ruleTypes -and $tenantScopes[0] -ne $tenantScopes[1]) {
                throw "Cannot safely combine guest types and tenant sets at '$PropertyPath' without broadening the targeting."
            }
        }
        # The all-external-tenants discriminator denotes the union's entire tenant set.
        if ($PropertyPath -like '*.externalTenants' -and ($Shared.membershipKind -eq 'all' -or $Rule.membershipKind -eq 'all')) {
            $all = if ($Shared.membershipKind -eq 'all') { $Shared } else { $Rule }
            Write-Output -NoEnumerate -InputObject $all
            return
        }
        $merged = [ordered]@{}
        $keys = @(@($Shared.Keys) + @($Rule.Keys) | Select-Object -Unique)
        foreach ($key in $keys) {
            if ($key -like '*@odata.context') { continue }
            $merged[$key] = Merge-MtConditionalAccessCondition -Shared $Shared[$key] -Rule $Rule[$key] -PropertyPath "$PropertyPath.$key"
        }
        Write-Output -NoEnumerate -InputObject $merged
        return
    }

    if ($Shared -is [System.Collections.IList] -and $Rule -is [System.Collections.IList]) {
        $union = [System.Collections.Generic.List[object]]::new()
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($value in @($Shared) + @($Rule)) {
            $key = ConvertTo-Json -InputObject $value -Depth 100 -Compress
            if ($seen.Add($key)) { $union.Add($value) }
        }
        # These collection properties use All as a wildcard, not an additional narrowing condition.
        if ($PropertyPath -match '\.(includeUsers|includeApplications|includePlatforms|includeLocations|clientAppTypes)$') {
            $all = @($union | Where-Object { $_ -is [string] -and $_ -eq 'all' })
            if ($all.Count -gt 0) { Write-Output -NoEnumerate -InputObject @($all[0]); return }
        }
        Write-Output -NoEnumerate -InputObject $union.ToArray()
        return
    }

    if ($Shared -is [string] -and [string]::IsNullOrWhiteSpace($Shared)) { Write-Output -NoEnumerate -InputObject $Rule; return }
    if ($Rule -is [string] -and [string]::IsNullOrWhiteSpace($Rule)) { Write-Output -NoEnumerate -InputObject $Shared; return }
    if (($Shared | ConvertTo-Json -Depth 100 -Compress) -ceq ($Rule | ConvertTo-Json -Depth 100 -Compress)) {
        Write-Output -NoEnumerate -InputObject $Shared
        return
    }
    if ($Shared -is [string] -and $Rule -is [string] -and
        $PropertyPath -match '\.(guestOrExternalUserTypes|insiderRiskLevels|agentIdRiskLevels|transferMethods)$') {
        $flags = @(@($Shared -split ',') + @($Rule -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
        return $flags -join ','
    }
    throw "Cannot safely combine Conditional Access plan and rule values at '$PropertyPath'. The inventory is incomplete; use a scenario evaluation for this condition instead of assuming coverage."
}
