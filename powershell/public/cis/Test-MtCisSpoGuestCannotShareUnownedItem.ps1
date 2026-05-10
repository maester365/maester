function Test-MtCisSpoGuestCannotShareUnownedItem {
    <#
    .SYNOPSIS
        Ensure that SharePoint guest users cannot share items they don't own

    .DESCRIPTION
        7.2.5 (L2) Ensure that SharePoint guest users cannot share items they don't own
        CIS Microsoft 365 Foundations Benchmark v6.0.1

    .EXAMPLE
        Test-MtCisSpoGuestCannotShareUnownedItem

        Returns true if SharePoint guest users cannot share items they don't own

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoGuestCannotShareUnownedItem
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing that SharePoint guest users cannot share items they don't own..."

    $return = $true
    try {
        $PreventExternalUsersFromResharing = Get-PnPTenant | Select-Object -ExpandProperty PreventExternalUsersFromResharing
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