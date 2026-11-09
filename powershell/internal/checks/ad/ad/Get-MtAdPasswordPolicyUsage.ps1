function Get-MtAdPasswordPolicyUsage {
    <#
    .SYNOPSIS
    Counts visible enabled users by their computed resultant fine-grained policy DN.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Users, [Parameter(Mandatory)] $Policies)

    $counts = @{}
    foreach ($policy in @($Policies)) {
        if ([string]::IsNullOrWhiteSpace([string]$policy.DistinguishedName)) {
            throw 'A fine-grained password policy has no distinguished name.'
        }
        if ($null -eq $policy.PSObject.Properties['MsDsPsoAppliesTo'] -or $null -eq $policy.PSObject.Properties['MsDsPasswordSettingsPrecedence']) {
            throw "Fine-grained password policy '$($policy.DistinguishedName)' lacks direct targets or precedence metadata."
        }
        $counts[[string]$policy.DistinguishedName] = 0
    }
    $enabledCount = 0
    $defaultCount = 0
    foreach ($user in @($Users)) {
        if ($null -eq $user.PSObject.Properties['Enabled'] -or $null -eq $user.Enabled) {
            throw 'User Enabled field is missing; cannot establish policy usage.'
        }
        if (-not $user.Enabled) { continue }
        $enabledCount++
        if ($null -eq $user.PSObject.Properties['ResultantPasswordPolicyDN']) {
            throw "ResultantPasswordPolicyDN is missing for enabled user '$($user.Name)'."
        }
        $dn = [string]$user.ResultantPasswordPolicyDN
        if ([string]::IsNullOrWhiteSpace($dn)) { $defaultCount++; continue }
        if (-not $counts.ContainsKey($dn)) {
            throw "Resultant password policy '$dn' for user '$($user.Name)' is absent from the collected PSO inventory."
        }
        $counts[$dn]++
    }
    return [pscustomobject]@{ Counts = $counts; EnabledCount = $enabledCount; DefaultCount = $defaultCount }
}
