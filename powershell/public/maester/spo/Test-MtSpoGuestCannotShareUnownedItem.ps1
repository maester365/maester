<#
.SYNOPSIS
    Ensure that SharePoint guest users cannot share items they don't own

.DESCRIPTION
    By default, external users can share items they don't own. This means that if a guest user has access to an item, they can share it with others, potentially leading to unauthorized access and data leaks. By preventing external users from resharing items they don't own, you can help protect sensitive information and maintain better control over who has access to your SharePoint resources. The recommended state is PreventExternalUsersFromResharing set to $true.

.EXAMPLE
    Test-MtSpoGuestCannotShareUnownedItem

    Returns true if the SharePoint tenant is integrated with Microsoft Entra B2B, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtSpoGuestCannotShareUnownedItem
#>
function Test-MtSpoGuestCannotShareUnownedItem {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing that SharePoint guest users cannot share items they don't own..."

    $return = $true
    try {
        $PreventExternalUsersFromResharing  = Get-SPOTenant | Select-Object -ExpandProperty PreventExternalUsersFromResharing
        if ($PreventExternalUsersFromResharing) {
            $testResult = "Well done. External users cannot share items they don't own."
        } else {
            $testResult = "External users can share items they don't own."
            $return = $false
        }
        Add-MtTestResultDetail -Result $testResult
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}