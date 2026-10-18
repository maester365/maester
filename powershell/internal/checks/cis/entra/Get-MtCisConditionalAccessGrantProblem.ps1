function Get-MtCisConditionalAccessGrantProblem {
    <#
    .SYNOPSIS
        Returns the grant control problems of a Conditional Access policy.

    .DESCRIPTION
        A block cannot be combined with other grant controls. When a policy requires multifactor authentication or an
        authentication strength together with another grant control, the grant operator must be AND, because with OR
        one control alone would satisfy the policy.

    .PARAMETER Policy
        A Conditional Access policy as returned by Get-MtConditionalAccessPolicy.

    .EXAMPLE
        Get-MtCisConditionalAccessGrantProblem -Policy $policy

        Returns no text when the grant controls of the policy work together as required.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [object] $Policy
    )

    $grant = $Policy.grantControls
    $builtIn = @($grant.builtInControls | Where-Object { $_ })
    $strength = [bool]$grant.authenticationStrength.id
    $controlCount = $builtIn.Count + [int]$strength
    $problems = [System.Collections.Generic.List[string]]::new()
    if ($builtIn -contains 'block' -and $controlCount -gt 1) {
        $problems.Add('block is combined with other grant controls')
    }
    $requiresMfa = ($builtIn -contains 'mfa') -or $strength
    if ($requiresMfa -and $controlCount -gt 1 -and $grant.operator -ne 'AND') {
        $problems.Add('grant operator is OR')
    }

    return [string[]]$problems.ToArray()
}
