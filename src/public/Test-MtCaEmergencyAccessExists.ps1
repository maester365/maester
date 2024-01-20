<#
 .Synopsis
  Checks if the tenant has at least one emergency account or account group excluded from all conditional access policies

 .Description
  It is recommended to have at least one emergency account or account group excluded from all conditional access policies.
  This allows for emergency access to the tenant in case of a misconfiguration or other issues.

  Learn more:
  https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access

 .Example
  Test-MtCaEmergencyAccessExists
#>

Function Test-MtCaEmergencyAccessExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    Set-StrictMode -Off
    $policies = Get-MtConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" }

    $result = $false
    $PolicyCount = $policies | Measure-Object | Select-Object -ExpandProperty Count
    $ExcludedUsers = $policies.conditions.users.excludeUsers | Group-Object -NoElement | Sort-Object -Property Count -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Count
    $ExcludedGroups = $policies.conditions.users.excludeGroups | Group-Object -NoElement | Sort-Object -Property Count -Descending | Select-Object -First 1 | Select-Object -ExpandProperty Count
    # If the number of enabled policies is not the same as the number of excluded users or groups, there is no emergency access
    if ($PolicyCount -eq $ExcludedUsers -or $PolicyCount -eq $ExcludedGroups) {
        $result = $true
    }

    Set-StrictMode -Version Latest

    return $result
}