function Test-MtAdGpoBlockedInheritanceCount {
    <#
    .SYNOPSIS
    Counts targets blocking GPO inheritance.

    .DESCRIPTION
    This test retrieves Active Directory Organizational Units (OUs) and counts how many targets
    are configured to block Group Policy Object (GPO) inheritance.

    Blocked inheritance is set on OUs via the `gpOptions` attribute.
    When `gpOptions -eq 1`, GPO inheritance is blocked for that OU.

    Blocking inheritance can create security gaps because settings from parent OUs won't apply.
    Policies can become “sticky” at lower levels, so blocked inheritance should be monitored and
    justified.

    .EXAMPLE
    Test-MtAdGpoBlockedInheritanceCount

    Returns $true when no OUs are blocking GPO inheritance, $false when blocked inheritance is present.
    The test result includes the blocked OU count.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoBlockedInheritanceCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = $null
    try {
        $adState = Get-MtADDomainState
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError "Active Directory data is not available."
        return $null
    }

    $ous = $null
    try {
        $ous = Get-ADOrganizationalUnit -Filter * -Properties gpOptions -ErrorAction Stop
    }
    catch {
        Write-Verbose "Unable to retrieve Organizational Units for blocked inheritance check: $($_.Exception.Message)"
        $ous = $null
    }

    $ouCount = if ($null -ne $ous) { ($ous | Measure-Object).Count } else { 0 }

    $blockedOus = @()
    if ($null -ne $ous) {
        $blockedOus = @(
            foreach ($ou in $ous) {
                $gpOptionsValue = $ou.gpOptions
                if ($null -eq $gpOptionsValue) {
                    continue
                }

                # gpOptions: 1 = blocked inheritance
                if ([int]$gpOptionsValue -eq 1) {
                    $ou
                }
            }
        )
    }

    $blockedCount = ($blockedOus | Measure-Object).Count
    $blockedPercentage = if ($ouCount -gt 0) { [math]::Round(($blockedCount / $ouCount) * 100, 2) } else { 0 }

    # Security intent: pass only when no OU is blocking GPO inheritance.
    $testResult = $blockedCount -eq 0

    $sampleLimit = 5
    $sampleBlocked = $blockedOus | Select-Object -First $sampleLimit
    $sampleNames = @($sampleBlocked | ForEach-Object {
        if ($_.Name) { $_.Name } else { $_.DistinguishedName }
    })
    $sampleNamesText = ($sampleNames | Where-Object { $_ }) -join ', '
    if ($blockedCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total OUs | $ouCount |`n"
    $resultTable += "| OUs Blocking Inheritance | $blockedCount |`n"
    $resultTable += "| Blocked Ratio | $blockedPercentage% |`n"
    if ($blockedCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample Blocked OUs | $sampleNamesText |`n"
    }

    if ($testResult) {
        $recommendation = "✅ GPO inheritance blocking was not detected on any OU. Active Directory Group Policy Objects have been analyzed successfully."
    }
    else {
        $recommendation = "⚠️ GPO inheritance blocking was detected on $blockedCount OU(s). Blocked inheritance can create security gaps because policies from parent OUs won't apply. Review and justify these OU configurations."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
