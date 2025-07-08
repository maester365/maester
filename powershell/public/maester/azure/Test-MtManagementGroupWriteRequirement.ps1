function Test-MtManagementGroupWriteRequirement {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Azure)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    try {
        $mgResponse = Invoke-MtAzureRequest `
            -RelativeUri "/providers/Microsoft.Management/managementGroups" `
            -ApiVersion "2020-05-01"

        $mgList = $mgResponse.value
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    $rootGroup = $mgList | Where-Object { $_.properties.displayName -eq "Tenant Root Group" }

    if (-not $rootGroup) {
        Add-MtTestResultDetail -SkippedBecause "Tenant Root Group not found"
        return $null
    }

    $rootMgId = $rootGroup.name

    try {
        $settingResponse = Invoke-MtAzureRequest `
            -RelativeUri "/providers/Microsoft.Management/managementGroups/$rootMgId/settings/default" `
            -ApiVersion "2020-05-01"

        $requireWritePermissions = $settingResponse.properties.requireAuthorizationForGroupCreation

        $testResult = $requireWritePermissions -eq $true

        if ($testResult) {
            $testResultMarkdown = "Write permissions are required for creating new management groups."
        } else {
            $testResultMarkdown = "Write permissions are NOT required for creating new management groups. Anyone in the tenant may create them."
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
