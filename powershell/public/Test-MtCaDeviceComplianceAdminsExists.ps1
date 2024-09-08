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

.LINK
    https://maester.dev/docs/commands/Test-MtCaDeviceComplianceAdminsExists
#>
function Test-MtCaDeviceComplianceAdminsExists {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plural.')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'PSScriptAnalyzer bug is not detecting usage of PolicyIncludesAllRoles')]
  [CmdletBinding()]
  [OutputType([bool])]
  param ()

  if ( ( Get-MtLicenseInformation EntraID ) -eq "Free" ) {
    Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
    return $null
  }

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

  $testDescription = "
Microsoft recommends requiring device compliance for administrators that are members of the following roles:

* Global administrator
* Application administrator
* Authentication Administrator
* Billing administrator
* Cloud application administrator
* Conditional Access administrator
* Exchange administrator
* Helpdesk administrator
* Password administrator
* Privileged authentication administrator
* Privileged Role Administrator
* Security administrator
* SharePoint administrator
* User administrator

See [Require compliant or Microsoft Entra hybrid joined device for administrators - Microsoft Learn](https://aka.ms/CATemplatesAdminDevices)"
  $testResult = "These conditional access policies require compliant or Microsoft Entra hybrid joined device for administrators:`n`n"

  $result = $false
  foreach ($policy in $policies) {
    $PolicyIncludesAllRoles = $true
    $AdministrativeRolesToCheck | ForEach-Object {
      if ( ( $_ -notin $policy.conditions.users.includeRoles `
            -and $policy.conditions.users.includeUsers -ne 'All' ) `
          -or $_ -in $policy.conditions.users.excludeRoles `
      ) {
        $PolicyIncludesAllRoles = $false
      }
    }
    if ( 'domainJoinedDevice' -in $policy.grantcontrols.builtincontrols `
        -and 'compliantDevice' -in $policy.grantcontrols.builtincontrols `
        -and $policy.grantControls.operator -eq "OR" `
        -and $PolicyIncludesAllRoles `
        -and $policy.conditions.applications.includeApplications -eq "All" `
    ) {
      Write-Verbose -Message "Found a conditional access policy requiring device compliance for admins: $($policy.displayname)"
      $testResult += "  - [$($policy.displayname)](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($($policy.id))?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
      $result = $true
    }
  }

  if ($result -eq $false) {
    $testResult = "There was no conditional access policy requiring compliant or Microsoft Entra hybrid joined device for administrators."
  }
  Add-MtTestResultDetail -Description $testDescription -Result $testResult

  return $result
}