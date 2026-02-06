<#
.SYNOPSIS
    Checks if minimum one dynamic group exists with a membership rule targeting guest users.

.DESCRIPTION
    There should be minimum one dynamic group with a membership rule targeting guest users to ensure that guest users are easily identifiable and can be managed effectively.
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisEnsureGuestUserDynamicGroup

    Returns true if a group with a membership rule targeting guest users exists.

.LINK
    https://maester.dev/docs/commands/Test-MtCisEnsureGuestUserDynamicGroup
#>
function Test-MtCisEnsureGuestUserDynamicGroup {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        Write-Verbose 'Getting settings...'
        $groups = Invoke-MtGraphRequest -RelativeUri "groups" -DisableCache | Where-Object { $_.groupTypes -contains "DynamicMembership" }

        Write-Verbose 'Executing checks'
        $checkGuestUserGroup = $groups | Where-Object { $_.MembershipRule -like "*(user.userType -eq `"Guest`")*" }

        $testResult = (($checkGuestUserGroup | Measure-Object).Count -ge 1)

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant settings not comply with CIS recommendations.`n`n%TestResult%"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjects $checkGuestUserGroup -GraphObjectType Groups
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}