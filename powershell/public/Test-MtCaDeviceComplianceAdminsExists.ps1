<#
 .Synopsis
  Checks if the tenant has at least one conditional access policy requiring device compliance for admins.

 .Description
  Device compliance conditional access policy can be used to require devices to be compliant or hybrid Azure AD joined for admins.
  This is a good way to prevent AITM attacks.

  Learn more:
  https://aka.ms/CATemplatesAdminDevices

 .Example
  Test-MtCaDeviceComplianceAdminsExists
#>

Function Test-MtCaDeviceComplianceAdminsExists {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification='Exists is not a plural.')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='PSScriptAnalyzer bug is not detecting usage of PolicyIncludesAllRoles')]
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  $AdministrativeRolesToCheck = @(
    "62e90394-69f5-4237-9190-012177145e10",
    "194ae4cb-b126-40b2-bd5b-6091b380977d",
    "f28a1f50-f6e7-4571-818b-6a12f2af6b6c",
    "29232cdf-9323-42fd-ade2-1d097af3e4de",
    "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9",
    "729827e3-9c14-49f7-bb1b-9608f156bbb8",
    "b0f54661-2d74-4c50-afa3-1ec803f12efe",
    "fe930be7-5e62-47db-91af-98c3a49a38b1",
    "c4e39bd9-1100-46d3-8c65-fb160da0071f",
    "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3",
    "158c047a-c907-4556-b7ef-446551a6b5f7",
    "966707d0-3269-4727-9be2-8c3a10f19b9d",
    "7be44c8a-adaf-4e2a-84d6-ab2649e08a13",
    "e8611ab8-c189-46e8-94e1-60213ab1f814"
  )

  $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

  $result = $false
  foreach ($policy in $policies) {
    $PolicyIncludesAllRoles = $true
    $AdministrativeRolesToCheck | ForEach-Object {
      if ( $_ -notin $policy.conditions.users.includeRoles  ) {
        $PolicyIncludesAllRoles = $false
      }
    }
    if ( 'domainJoinedDevice' -in $policy.grantcontrols.builtincontrols `
        -and 'compliantDevice' -in $policy.grantcontrols.builtincontrols `
        -and $policy.grantControls.operator -eq "OR" `
        -and $PolicyIncludesAllRoles `
        -and $policy.conditions.applications.includeApplications -eq "All" `
    ) {
      $result = $true
    }
  }

  return $result
}