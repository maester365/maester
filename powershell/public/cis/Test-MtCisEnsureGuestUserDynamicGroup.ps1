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

        $resultMd = "| Group(s) |`n"
        $resultMd += "| --- |`n"

        foreach ($group in $checkGuestUserGroup) {
            $resultMd += "| $($group.DisplayName) |`n"
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjects $checkGuestUserGroup -GraphObjectType Groups
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}