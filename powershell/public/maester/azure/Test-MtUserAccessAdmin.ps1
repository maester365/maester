<#
.SYNOPSIS
    Checks if any Global Admins have User Access Control permissions at the Root Scope

.DESCRIPTION
    Ensure that no one has permanent access to all subscriptions through the Root Scope.

.EXAMPLE
    Test-MtUserAccessAdmin

    Returns true if no User Access Control permissions are assigned at the root scope

.LINK
    https://maester.dev/docs/commands/Test-MtUserAccessAdmin
#>
function Test-MtUserAccessAdmin {

    Write-Verbose "Checking if connected to Graph"
    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    if(!(Test-MtConnection Azure)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    Write-Verbose "Getting all User Access Administrators at Root Scope"
    try {
        $result = Get-AzRoleAssignment -Scope "/" -RoleDefinitionName 'User Access Administrator' -ErrorAction Stop
    } catch {
        Write-Error "Failed to retrieve role assignments at root scope"
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    $resultObject = $result

    # Get the count of role assignments
    $roleAssignmentCount = $resultObject.Count

    $testResult = $roleAssignmentCount -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no User Access Administrators:`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant has $roleAssignmentCount User Access Administrators:`n`n%TestResult%"
    }
    # $itemCount is used to limit the number of returned results shown in the table
    $itemCount = 0
    $resultMd = "| Display Name | User Access |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $resultObject) {
        $itemCount += 1
        $itemResult = "❌ Fail"
        # We are restricting the table output to 50 below as it could be extremely large
        if ($itemCount -lt 51) {
            $resultMd += "| $($item.SignInName) | $($itemResult) |`n"
        }
    }
    # Add a limited results message if more than 6 results are returned
    if ($itemCount -gt 50) {
        $resultMd += "Results limited to 50`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
