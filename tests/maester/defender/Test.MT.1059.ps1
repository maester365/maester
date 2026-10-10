function Get-MtMdiHealthIssueInstance {
    <#
    .SYNOPSIS
    Returns one MT.1059 instance per Microsoft Defender for Identity health issue.

    .DESCRIPTION
    Instance source of the MT.1059 family. Keeps the latest entry of each health issue per domain and
    sensor, then groups the entries by display name. The suffix is the MD5 hash of the display name
    (MT.1059.<hash>), the title and the Severity:<severity> and display-name tags are those of the
    Maester 2.x rows, and the severity is the one Defender for Identity reports for the issue.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    try {
        $response = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'security/identities/healthIssues' -OutputType Hashtable -ErrorAction Stop
    } catch {
        # Maester 2.x showed no rows here. Defender for Identity is not enabled, or the app lacks the permission.
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Microsoft Defender for Identity health issues could not be read. Defender for Identity may not be enabled in this tenant, or the SecurityIdentitiesHealth.Read.All permission is missing. Details: $($_.Exception.Message)"
    }
    $allHealthIssues = @($response.value | Where-Object { $_ })

    # Add domainNames and sensorDNSNames as string properties to identify unique health issues
    $allHealthIssues | ForEach-Object {
        $_ | Add-Member -NotePropertyName 'domainNamesString' -NotePropertyValue ($_.domainNames -join ',') -Force
        $_ | Add-Member -NotePropertyName 'sensorDNSNamesString' -NotePropertyValue ($_.sensorDNSNames -join ',') -Force
    }

    # Get unique health issues (duplicated entries will be created when status of an issue has been changed)
    $textInfo = (Get-Culture).TextInfo
    $healthIssues = [System.Collections.Generic.List[Object]]::new()
    $allHealthIssues | Group-Object -Property displayName, domainNamesString, sensorDNSNamesString | ForEach-Object {
        $uniqueHealthIssue = $_.Group | Sort-Object -Property createdDateTime -Descending | Select-Object -First 1
        $uniqueHealthIssue.severity = $textInfo.ToTitleCase($uniqueHealthIssue.severity) # We need title case to be compatible with Maester report
        $uniqueHealthIssue.status = $textInfo.ToTitleCase($uniqueHealthIssue.status) # It just looks better...
        $healthIssues.Add($uniqueHealthIssue) | Out-Null
    }

    # Group all latest issues based on displayName to group sensors based on particular issue
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $utf8 = [System.Text.UTF8Encoding]::new()
    foreach ($issueGroup in ($healthIssues | Group-Object -Property displayName)) {
        $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($issueGroup.Name))).ToLower() -replace '-', ''
        $severity = $issueGroup.Group[0].severity
        [pscustomobject]@{
            Id       = $hash
            Title    = "MDI Health Issues - $($issueGroup.Name)."
            Severity = $severity
            Tag      = @("Severity:$severity", $issueGroup.Name)
            Data     = $issueGroup
        }
    }
}

function Test-MtMdiHealthIssue {
    <#
    .SYNOPSIS
    Checks that a Microsoft Defender for Identity health issue has been resolved.

    .DESCRIPTION
    Runs once per Defender for Identity health issue (grouped by display name). Fails when any sensor or
    domain still has the issue open. Skipped when every alert of the issue is suppressed or dismissed.

    .LINK
    https://maester.dev/docs/tests/MT.1059
    #>
    [MaesterTest(
        Id = 'MT.1059',
        Title = 'Microsoft Defender for Identity health issues should be resolved',
        Severity = 'Medium',
        Category = 'Defender for Identity health issues',
        Product = 'Defender',
        Tag = ('Defender', 'Maester', 'MDI'),
        Service = 'Graph',
        InstanceSource = 'Get-MtMdiHealthIssueInstance',
        Author = 'Cloud-Architekt',
        Contributor = ('thomas-s-schmidt', 'SamErde')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The health issue group to check, supplied by the engine.
        $Instance
    )

    $issueName = $Instance.Data.Name
    $issues = $Instance.Data.Group

    #region Add detailed test description
    $recommendationSteps = foreach ($recommendationStep in $issues[0].recommendations) {
        "$($issues[0].recommendations.IndexOf($recommendationStep) + 1). ${recommendationStep}"
    }
    $recommendationSteps = $recommendationSteps -join "`n`n"

    $relatedLinksMd = '* [Microsoft Defender for Identity health issues](https://learn.microsoft.com/defender-for-identity/health-alerts)', '* [Health issues - Microsoft Defender](https://security.microsoft.com/identities/health-issues)'
    $relatedLinksMd = $relatedLinksMd -join "`n"

    $description = $null
    if ($issues.additionalInformation) {
        $description = $issues[0].description
    }
    $descriptionMd = $issueName + "`n`n" + $description + "`n`n" + "`n`n#### Remediation actions:`n`n" + $recommendationSteps + "`n`n#### Related links:`n`n" + $relatedLinksMd
    #endregion

    #region Add detailed test result
    if ('Open' -in $issues.status) {
        $result = $false
        $resultMd = "$($issues.status.Where({$_ -eq 'Open'}).count) of $($issues.status.count) has issues."
    } else {
        $result = $true
        $resultMd = 'Well done! All issues has been resolved.'
    }
    $resultMdTable = ''
    if ($issues.sensorDNSNames -is [System.Collections.IEnumerable]) {
        $resultMdTable += "`n`n#### Sensor DNS names"
        $resultMdTable += "`n`n| Sensor | Status | Created | Last Update |"
        $resultMdTable += "`n| --- | --- | --- | --- |"
        foreach ($issue in $issues) {
            if ($issue.status -eq 'Closed') {
                $issueStatusMd = "✅ $($issue.status)"
            } elseif ($issue.status -eq 'Open') {
                $issueStatusMd = "❌ $($issue.status)"
            } else {
                $issueStatusMd = "🗄️ $($issue.status)"
            }
            foreach ($sensorDNSName in $issue.sensorDNSNames) {
                $resultMdTable += "`n| $($sensorDNSName) | ${issueStatusMd} | $($issue.createdDateTime) | $($issue.lastModifiedDateTime)"
            }
        }
    }
    if ($issues.domainNames -is [System.Collections.IEnumerable]) {
        $resultMdTable += "`n`n#### Domain names"
        $resultMdTable += "`n`n| Domain | Status | Created | Last Update |"
        $resultMdTable += "`n| --- | --- | --- | --- |"
        foreach ($issue in $issues) {
            if ($issue.status -eq 'Closed') {
                $issueStatusMd = "✅ $($issue.status)"
            } elseif ($issue.status -eq 'Open') {
                $issueStatusMd = "❌ $($issue.status)"
            } else {
                $issueStatusMd = "🗄️ $($issue.status)"
            }
            foreach ($domainName in $issue.domainNames) {
                $resultMdTable += "`n| $($domainName) | ${issueStatusMd} | $($issue.createdDateTime) | $($issue.lastModifiedDateTime)"
            }
        }
    }
    if ($issues.additionalInformation.misconfiguredObjectTypes -is [System.Collections.IEnumerable]) {
        $resultMdTable += '#### Objects'
        $resultMdTable += "`n`n| Object | Status | Permissions | Last Validated |"
        $resultMdTable += "`n| --- | --- | --- | --- |"
        foreach ($issue in $issues) {
            if ($issue.status -eq 'Closed') {
                $issueStatusMd = '✅'
            } elseif ($issue.status -eq 'Open') {
                $issueStatusMd = '❌'
            } else {
                $issueStatusMd = '🗄️'
            }
            foreach ($object in $issue.additionalInformation.misconfiguredObjectTypes) {
                $resultMdTable += "`n| $($object) | ${issueStatusMd} | $($issue.additionalInformation.missingPermissions -join ', ') | $($issue.additionalInformation.validatedOn)"
            }
        }
    }
    $resultMdLink = "`n`n➡️ Open [Health issue - $($issueName)](https://security.microsoft.com/identities/health-issues) in the Microsoft Defender portal."
    #endregion

    #region Skip if all alerts are dismissed or suppressed
    if (-not ($issues.status -notmatch 'Dismissed') -or -not ($issues.status -notmatch 'Suppressed')) {
        Add-MtTestResultDetail -Description $descriptionMd -SkippedBecause Custom -SkippedCustomReason "All alerts within this health issue has been **Suppressed** by an administrator.${resultMdTable}`n`nIf this issue is valid for your MDI instance, you can change it's state from **Suppressed** to **Re-open** in the [Microsoft Defender portal](https://security.microsoft.com/identities/health-issues)."
        return $null
    }
    #endregion

    Add-MtTestResultDetail -Description $descriptionMd -Result ($resultMd + $resultMdTable + $resultMdLink) -Severity $Instance.Severity

    return $result
}
