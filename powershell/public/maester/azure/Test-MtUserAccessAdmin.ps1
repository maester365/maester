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
    [CmdletBinding()]
    [OutputType([bool])]
    param()

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
        $userAccessResult = Invoke-MtAzureRequest -RelativeUri 'providers/Microsoft.Authorization/roleAssignments' -Filter 'atScope()' -ApiVersion '2022-04-01'
        $userAccessAdmins = Get-ObjectProperty $userAccessResult 'value'

        # Get the count of role assignments
        $roleAssignmentCount = $userAccessAdmins | Measure-Object | Select-Object -ExpandProperty Count

        $testResult = $roleAssignmentCount -eq 0

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant has no User Access Administrators."
        }
        else {
            $testResultMarkdown = "Your tenant has $roleAssignmentCount resource(s) with access to manage access to all Azure subscriptions and management groups in this tenant.`n`n"

            $testResultMarkdown += Get-MtDirectoryObjects $userAccessAdmins.properties.principalId -AsMarkdown
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

}
