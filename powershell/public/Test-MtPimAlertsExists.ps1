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
    # The AlertId that should be use as filter: All
    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("RedundantAssignmentAlert", "RolesAssignedOutsidePimAlert", "SequentialActivationRenewalsAlert", "TooManyGlobalAdminsAssignedToTenantAlert", "StaleSignInAlert")]
    [string[]]$AlertId = "All",

    # The Enterprise Access Model level which should be considered for the filter
    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [ValidateSet("ControlPlane", "ManagementPlane")]
    [string[]]$FilteredAccessLevel = $null,

    # The Enterprise Access Model level which should be considered for the filter
    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [object[]]$FilteredBreakGlassObjectIds = $null
  )

  $mgContext = Get-MgContext
  $tenantId = $mgContext.TenantId

  $Alerts = Invoke-MtGraphRequest -RelativeUri "privilegedAccess/aadroles/resources/$($tenantId)/alerts" -ApiVersion beta | Where-Object { $_.status -eq "Active" }

  if ($AlertId -ne "All") {
    $Alerts = $Alerts | Where-Object { $_.id -eq $AlertId }
  }

  if ($null -ne $FilteredAccessLevel) {
    $EamClassification = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json' | ConvertFrom-Json -Depth 10
    $FilteredClassification = ($EamClassification | Where-Object { $_.Classification.EAMTierLevelName -eq $FilteredAccessLevel }).RoleId
    $AffectedRoleAssignments = $alerts.additionalData | ForEach-Object { $_.item }
    $Alerts = $Alerts.additionalData | ForEach-Object { $_.item | Where-Object { $_.RoleTemplateId -in $FilteredClassification } }

    $Alerts.additionalData | ForEach-Object { $_.item | Where-Object { $_.RoleTemplateId -eq "62e90394-69f5-4237-9190-012177145e10" } }
    $AffectedRoleAssignments | ForEach-Object { $_ | Where-Object { $_.RoleTemplateId -eq "62e90394-69f5-4237-9190-012177145e10" } }
  }

  if ($Alerts.Count -gt "0") {

    Write-Warning "HAFDJADFSKDFKSFKJFD"

    $testDescription = "

    ## Security Impact
    $($Alerts.securityImpact)

    ## Mitigation steps
    $($Alerts.mitigationSteps)

    ## How to prevent
    $($Alerts.howToPrevent)

    ## Details of the alert in Azure Portal
    $($Alerts.howToPrevent)
    "

    $testResult = "$($Alerts.alertDescription):`n`n
    See [alert details of $($Alerts.alertName)](https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/AlertDetail/providerId/aadroles/alertId/$($AlertId)/resourceId/$($tenantId))
    "

    Add-MtTestResultDetail -Description $testDescription -Result $testResult
    Write-Verbose "$testdescription - $testresult"
  }
  return $Alerts
}

