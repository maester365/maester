Function Test-MtPimAlertsExists {
  [OutputType([object])]
  <#
 .Synopsis
  Checks if PIM alerts exists

 .Description
  GET /beta/privilegedAccess/aadroles/resources/$tenantId/alerts

 .Example
  Test-MtPimAlertsExists -FilteredAccessLevel "ControlPlane" -AlertId "RolesAssignedOutsidePimAlert"
  #>

  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [ValidateSet("RedundantAssignmentAlert", "RolesAssignedOutsidePimAlert", "SequentialActivationRenewalsAlert", "TooManyGlobalAdminsAssignedToTenantAlert", "StaleSignInAlert")]
    [string[]]$AlertId,

    [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
    [ValidateSet("ControlPlane", "ManagementPlane")]
    [string[]]$FilteredAccessLevel = $null,

    [Parameter(ValueFromPipelineByPropertyName = $true, Position = 2)]
    [object[]]$FilteredBreakGlassUpn = (Get-MtUser -UserType EmergencyAccess).userPrincipalName
  )

  $mgContext = Get-MgContext
  $tenantId = $mgContext.TenantId

  $Alert = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/privilegedAccess/aadroles/resources/$($tenantId)/alerts" `
            | Select-Object -ExpandProperty value -ErrorAction SilentlyContinue | Where-Object { $_.id -eq $AlertId }

  $AffectedRoleAssignments = $Alert.additionalData | ForEach-Object {
    $CurrentItem = $_['item']
    $result = New-Object psobject;
    foreach ($entry in $CurrentItem.GetEnumerator()) {
        $result | Add-Member -MemberType NoteProperty -Name $entry.key -Value $entry.value -Force
      }
      $result
  }

  # Filtering based on (EntraOps) Enterprise Access Model Tiering
  if ($null -ne $FilteredAccessLevel) {
    $EamClassification = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json' | ConvertFrom-Json -Depth 10
    $FilteredClassification = ($EamClassification | Where-Object { $_.Classification.EAMTierLevelName -eq $FilteredAccessLevel }).RoleId
    $AffectedRoleAssignments = $AffectedRoleAssignments | Where-Object { $_.RoleTemplateId -in $FilteredClassification }
  }

  # Exclude Break Glass from Alerts
  if ($null -ne $FilteredBreakGlassUpn -and $null -eq $AffectedRoleAssignments) {
    $AffectedRoleAssignments | Where-Object {$_.AssigneeUserPrincipalName -in $($FilteredBreakGlassUpn)} | ForEach-Object {
      Write-Warning "$($_.AssigneeDisplayName) has been defined as Break Glass and removed from $($Alert.id)"
    }
    $AffectedRoleAssignments = $AffectedRoleAssignments | Where-Object {$_.AssigneeUserPrincipalName -notin $($FilteredBreakGlassUpn)}
  }

  if ($Alert.Count -gt "0" -and $AffectedRoleAssignments.Count -gt 0) {
    $testDescription = "

**Security Impact**`n`n
$($Alert.securityImpact)

**Mitigation steps**`n`n
$($Alert.mitigationSteps)

**How to prevent**`n`n
$($Alert.howToPrevent)
"

$testResult = "$($Alert.alertDescription):`n`n
$($AffectedRoleAssignments | Format-List) `n`n
See [alert details of $($Alert.alertName)](https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/AlertDetail/providerId/aadroles/alertId/$($AlertId)/resourceId/$($tenantId))
"

  Add-MtTestResultDetail -Description $testDescription -Result $testResult
  }
  return $Alert
}