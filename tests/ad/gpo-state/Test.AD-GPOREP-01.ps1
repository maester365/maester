function Test-MtAdGpoNoPermissionsCount {
    <#
    .SYNOPSIS
    Counts Group Policy Objects (GPOs) with missing permissions.

    .DESCRIPTION
    This test retrieves GPO state data and counts how many GPO reports indicate that
    permissions are not present.

    .EXAMPLE
    Test-MtAdGpoNoPermissionsCount

    Returns $true when no GPOs are missing permissions, otherwise $false.
    The test result includes a markdown table with the count.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoPermissionsCount
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-01',
        Title = 'No GPOs should be missing permissions',
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

    Write-Verbose "Starting Test-MtAdGpoNoPermissionsCount"
    $gpoState = $null
    $gpoState = Get-MtADGpoState
Write-Verbose "Retrieved AD state"

if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo no permissions count"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports | Where-Object { $null -ne $_ })
    # PermissionsPresent is $null when the security descriptor of a GPO could not be read: unknown, not missing.
    $reportsWithNoPermissions = @($gpoReports | Where-Object { $false -eq $_.PermissionsPresent })
    $reportsNotEvaluated = @($gpoReports | Where-Object { $null -eq $_.PermissionsPresent })
    $notEvaluatedCount = $reportsNotEvaluated.Count

    if ($notEvaluatedCount -eq $gpoReports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read from Active Directory (0 of $($gpoReports.Count) GPOs evaluated), so this test could not be evaluated."
        return $null
    }

    $noPermissionsCount = ($reportsWithNoPermissions | Measure-Object).Count
    $testResult = $noPermissionsCount -eq 0

    $sampleLimit = 5
    $sampleGpo = $reportsWithNoPermissions | Select-Object -First $sampleLimit
    $sampleNames = @($sampleGpo | ForEach-Object {
        $name = $null
        if ($_.PSObject.Properties.Name -contains 'Name') { $name = $_.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '' }
        $name
    }) | Where-Object { $_ }
    $sampleNamesText = ($sampleNames -join ', ')
    if ($noPermissionsCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |" + "`n"
    $resultTable += "| --- | --- |" + "`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |" + "`n"
    $resultTable += "| GPO Reports With No Permissions | $noPermissionsCount |" + "`n"
    if ($noPermissionsCount -gt 0 -and $sampleNamesText) {
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
        $recommendation = "ℹ️ No GPO reports were found with missing permissions among the GPOs that could be evaluated, but the permissions of $notEvaluatedCount GPO(s) could not be read. Review those GPOs manually."
    }
    elseif ($testResult) {
        $recommendation = '✅ No GPO reports were found with missing permissions. Active Directory GPO permissions were analyzed successfully.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found with missing permissions ($noPermissionsCount). Review and remediate GPO security so permissions are correctly applied to required principals."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:$needsInvestigation
    Write-Verbose "Completed Test-MtAdGpoNoPermissionsCount"
    return $testResult
}
