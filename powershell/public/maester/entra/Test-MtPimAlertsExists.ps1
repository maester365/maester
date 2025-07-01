<#
 .Synopsis
  Checks if PIM alerts exists

 .Description
  GET /beta/privilegedAccess/aadRoles/resources/$tenantId/alerts

 .Example
  Test-MtPimAlertsExists -FilteredAccessLevel "ControlPlane" -AlertId "RolesAssignedOutsidePimAlert"

.LINK
  https://maester.dev/docs/commands/Test-MtPimAlertsExists
#>
function Test-MtPimAlertsExists {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Exists is not a plurality')]
  [OutputType([object])]
  [CmdletBinding()]

  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [ValidateSet('RedundantAssignmentAlert', 'RolesAssignedOutsidePimAlert', 'SequentialActivationRenewalsAlert', 'TooManyGlobalAdminsAssignedToTenantAlert', 'StaleSignInAlert')]
    # ID for the alert to test.
    [string[]]$AlertId,

    [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
    [ValidateSet('ControlPlane', 'ManagementPlane')]
    # Filter based on Enterprise Access Model Tiering. Can be 'ControlPlane' and/or 'ManagementPlane'.
    [string[]]$FilteredAccessLevel = $null,

    [Parameter(ValueFromPipelineByPropertyName = $true, Position = 2)]
    # Specify break glass accounts to exclude. Defaults to automatic detection based on conditional access policy exclusions.
    [object[]]$FilteredBreakGlass = (Get-MtUser -UserType EmergencyAccess)
  )

  begin {
    $mgContext = Get-MgContext
    $tenantId = $mgContext.TenantId
  }

  process {

    try {
      # Get PIM Alerts and store as object to be used in the test
      Write-Verbose 'Getting PIM Alerts'
      $Alert = Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "privilegedAccess/aadRoles/resources/$($tenantId)/alerts" | Where-Object { $_.id -eq $AlertId }

      if ($Alert.Where({ $_.isActive -eq 'True' }).additionalData) {
        $AffectedRoleAssignments = $Alert.Where({ $_.isActive -eq 'True' }).additionalData | ForEach-Object {
          $CurrentItem = $_.item
          $result = New-Object psobject
          foreach ($entry in $CurrentItem.GetEnumerator()) {
            $result | Add-Member -MemberType NoteProperty -Name $entry.key -Value $entry.value -Force
          }
          $result
        }
      }

      # Filtering based on (EntraOps) Enterprise Access Model Tiering
      if ($null -ne $FilteredAccessLevel) {
        Write-Verbose 'Filtering based on Enterprise Access Model Tiering'
        $EamClassification = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json' | ConvertFrom-Json -Depth 10
        $FilteredClassification = ($EamClassification | Where-Object { $_.Classification.EAMTierLevelName -eq $FilteredAccessLevel }).RoleId
        $AffectedRoleAssignments = $AffectedRoleAssignments | Where-Object { $_.RoleTemplateId -in $FilteredClassification }
      }

      # Exclude Break Glass from Alerts
      if ($null -ne $FilteredBreakGlass -and $null -ne $AffectedRoleAssignments) {
        $AffectedRoleAssignments | Where-Object { $_.AssigneeId -in $($FilteredBreakGlass).Id } | ForEach-Object {
          Write-Verbose "$($_.AssigneeUserPrincipalName) has been defined as Break Glass and removed from $($Alert.id)"
        }
        $AffectedRoleAssignments = $AffectedRoleAssignments | Where-Object { $_.AssigneeId -notin $($FilteredBreakGlass).Id }
      }

      # Set number of affected Items to value of filtered items (for example, original alert has two affected items, but all of them are break glass and excluded from the test)
      $Alert.numberOfAffectedItems = $AffectedRoleAssignments.Count

      # Create test result and details
      $convertHtmlLinkToMD = '<a.*?href=["'']([^"'']*)["''][^>]*>([^<]*)<\/a>' # Regular expression to detect HTML links
      $testDescription = "

**Security Impact**`n`n
$($Alert.securityImpact -replace $convertHtmlLinkToMD, '[$2]($1)')

**Mitigation steps**`n`n
$($Alert.mitigationSteps -replace $convertHtmlLinkToMD, '[$2]($1)')

**How to prevent**`n`n
$($Alert.howToPrevent -replace $convertHtmlLinkToMD, '[$2]($1)')
"

      $AffectedRoleAssignmentSummary = @()
      $AffectedRoleAssignmentSummary += foreach ($AffectedRoleAssignment in $AffectedRoleAssignments) {
        if ($null -ne $AffectedRoleAssignment.AssigneeDisplayName -or $null -ne $AffectedRoleAssignment.RoleDisplayName) {
          "  -  $($AffectedRoleAssignment.AssigneeDisplayName) with $($AffectedRoleAssignment.RoleDisplayName) by AssigneeId $($AffectedRoleAssignment.AssigneeId)`n"
        } else {
          "  -  $($AffectedRoleAssignment.AssigneeName) ($($AffectedRoleAssignment.AssigneeUserPrincipalName))`n"
        }
      }

      if ($Alert.Count -gt '0' -and $AffectedRoleAssignments.Count -gt 0) {
        $testResult = "$($Alert.alertDescription)`n`n
$($AffectedRoleAssignmentSummary)
Get more details from the PIM alert [$($Alert.alertName)](https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/AlertDetail/providerId/aadroles/alertId/$($AlertId)/resourceId/$($tenantId)) in the Azure Portal.
"
      } else {
        $testResult = 'All privileged role assignments are managed by PIM. Well done!'
      }

      Add-MtTestResultDetail -Description $testDescription -Result $testResult
      return $Alert
    } catch {
      Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
      return $null
    }
  } # end process block
} # end function
