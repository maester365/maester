function Test-MtAdGpoInheritedPermissionsCount {
    <#
    .SYNOPSIS
    Counts GPO reports with inherited permissions.

    .DESCRIPTION
    This test retrieves GPO state data and counts how many GPO reports indicate that
    permissions are inherited.

    .EXAMPLE
    Test-MtAdGpoInheritedPermissionsCount

    Returns $true when no GPO reports are using inherited permissions, otherwise $false.
    The test result includes a markdown table with the count.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoInheritedPermissionsCount
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-09',
        Title = 'GPO inherited permissions count should be retrievable',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'access-control',
        ResourceType = 'GroupPolicy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoInheritedPermissionsCount"
    $gpoState = $null
    $gpoState = Get-MtADGpoState
Write-Verbose "Retrieved AD state"

if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo inherited permissions count"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports | Where-Object { $null -ne $_ })
    # HasInheritedPermissions is $null when the security descriptor of a GPO could not be read: unknown, not absent.
    $reportsWithInheritedPermissions = @($gpoReports | Where-Object { $true -eq $_.HasInheritedPermissions })
    $reportsNotEvaluated = @($gpoReports | Where-Object { $null -eq $_.HasInheritedPermissions })
    $notEvaluatedCount = $reportsNotEvaluated.Count

    if ($notEvaluatedCount -eq $gpoReports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read from Active Directory (0 of $($gpoReports.Count) GPOs evaluated), so this test could not be evaluated."
        return $null
    }

    $inheritedPermissionsCount = ($reportsWithInheritedPermissions | Measure-Object).Count
    $testResult = $inheritedPermissionsCount -eq 0

    $sampleLimit = 5
    $sampleGpo = $reportsWithInheritedPermissions | Select-Object -First $sampleLimit
    $sampleNames = @($sampleGpo | ForEach-Object {
        $name = $null
        if ($_.PSObject.Properties.Name -contains 'Name') { $name = $_.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '' }
        $name
    }) | Where-Object { $_ }
    $sampleNamesText = ($sampleNames -join ', ')
    if ($inheritedPermissionsCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |" + "`n"
    $resultTable += "| --- | --- |" + "`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |" + "`n"
    $resultTable += "| GPO Reports With Inherited Permissions | $inheritedPermissionsCount |" + "`n"
    if ($inheritedPermissionsCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample GPO Reports | $sampleNamesText |" + "`n"
    }
    if ($notEvaluatedCount -gt 0) {
        $notEvaluatedNames = @($reportsNotEvaluated | Select-Object -First $sampleLimit | ForEach-Object { [string]$_.Name }) -join ', '
        $resultTable += "| GPO Reports Not Evaluated (permissions could not be read) | $notEvaluatedCount |" + "`n"
        $resultTable += "| Sample GPO Reports Not Evaluated | $notEvaluatedNames |" + "`n"
    }

    # Nothing was flagged, but a GPO whose permissions could not be read is not a pass.
    $needsInvestigation = $testResult -and $notEvaluatedCount -gt 0
    if ($needsInvestigation) {
        $recommendation = "ℹ️ No GPO reports were found using inherited permissions among the GPOs that could be evaluated, but the permissions of $notEvaluatedCount GPO(s) could not be read. Review those GPOs manually."
    }
    elseif ($testResult) {
        $recommendation = '✅ No GPO reports were found using inherited permissions.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found using inherited permissions ($inheritedPermissionsCount). Review and explicitly define GPO permissions where appropriate."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:$needsInvestigation
    Write-Verbose "Completed Test-MtAdGpoInheritedPermissionsCount"
    return $testResult
}
