BeforeDiscovery {
    try {
        $MdiAllHealthIssues = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'security/identities/healthIssues' -OutputType Hashtable -ErrorVariable MdiSecurityApiError
    } catch {
        Write-Verbose "Authentication needed. Please call Connect-MgGraph."
        return $null
    }

    $MdiHealthIssues = [System.Collections.Generic.List[Object]]::new()

    # Add domainNames and sensorDNSNames as string properties to identify unique health issues
    $MdiAllHealthIssues | ForEach-Object {
        $_ | Add-Member -NotePropertyName 'domainNamesString' -NotePropertyValue ($_.domainNames -join ',') -Force
        $_ | Add-Member -NotePropertyName 'sensorDNSNamesString' -NotePropertyValue ($_.sensorDNSNames -join ',') -Force
    }

    # Get unique health issues (duplicated entries will be created when status of an issue has been changed)
    $textInfo = (Get-Culture).TextInfo
    $MdiAllHealthIssues | Group-Object -Property displayName, domainNamesString, sensorDNSNamesString | ForEach-Object {
        $UniqueHealthIssue = $_.Group | Sort-Object -Property createdDateTime -Descending | Select-Object -First 1
        $UniqueHealthIssue.severity = $textInfo.ToTitleCase($UniqueHealthIssue.severity) # We need title case to be compatible with Maester report
        $UniqueHealthIssue.status = $textInfo.ToTitleCase($UniqueHealthIssue.status) # It just looks better...
        $MdiHealthIssues.Add($UniqueHealthIssue) | Out-Null
    }
    # Group all latest issues based on displayName to group sensors based on particular issue
    $MdiHealthIssuesGrouped = $MdiHealthIssues | Group-Object -Property displayName
}

Describe "Defender for Identity health issues" -Tag "Maester", "Defender", "Security", "All", "MDI" -ForEach $MdiHealthIssuesGrouped {
    # We need to ID each grouped issue based on it's common displayName, so to keep it consistent and clean, we use MD5
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($_.Name))).ToLower() -replace '-', ''
    It "MT.1059.$($hash): MDI Health Issues - $($_.Name). See https://maester.dev/docs/tests/MT.1059" -Tag 'MT.1059', "Severity:$($_.Group[0].severity)", $_.Name {
        #region Add detailed test result
        if ('Open' -in $_.Group.status) {
            $result = $false
            $resultMd = "$($_.Group.status.Where({$_ -eq 'Open'}).count) of $($_.Group.status.count) has issues."
        } else {
            $result = $true
            $resultMd = 'Well done! All issues has been resolved.'
        }
        if ($_.Group.sensorDNSNames -is [System.Collections.IEnumerable]) {
            $resultMd += "`n`n#### Sensor DNS names"
            $resultMd += "`n`n| Sensor | Status | Created | Last Update |"
            $resultMd += "`n| --- | --- | --- | --- |"
            foreach ($issue in $_.Group) {
                if ($issue.status -eq 'Closed') {
                    $issueStatusMd = "✅ $($issue.status)"
                } elseif ($issue.status -eq 'Open') {
                    $issueStatusMd = "❌ $($issue.status)"
                } else {
                    $issueStatusMd = "🗄️ $($issue.status)"
                }
                foreach ($sensorDNSName in $issue.sensorDNSNames) {
                    $resultMd += "`n| $($sensorDNSName) | ${issueStatusMd} | $($issue.createdDateTime) | $($issue.lastModifiedDateTime)"
                }
            }
        }
        if ($_.Group.domainNames -is [System.Collections.IEnumerable]) {
            $resultMd += "`n`n#### Domain names"
            $resultMd += "`n`n| Domain | Status | Created | Last Update |"
            $resultMd += "`n| --- | --- | --- | --- |"
            foreach ($issue in $_.Group) {
                if ($issue.status -eq 'Closed') {
                    $issueStatusMd = "✅ $($issue.status)"
                } elseif ($issue.status -eq 'Open') {
                    $issueStatusMd = "❌ $($issue.status)"
                } else {
                    $issueStatusMd = "🗄️ $($issue.status)"
                }
                foreach ($domainName in $issue.domainNames) {
                    $resultMd += "`n| $($domainName) | ${issueStatusMd} | $($issue.createdDateTime) | $($issue.lastModifiedDateTime)"
                }
            }
        }
        if ($_.Group.additionalInformation.misconfiguredObjectTypes -is [System.Collections.IEnumerable]) {
            $resultMd += "#### Objects"
            $resultMd += "`n`n| Object | Status | Permissions | Last Validated |"
            $resultMd += "`n| --- | --- | --- | --- |"
            foreach ($issue in $_.Group) {
                if ($issue.status -eq 'Closed') {
                    $issueStatusMd = "✅"
                } elseif ($issue.status -eq 'Open') {
                    $issueStatusMd = "❌"
                } else {
                    $issueStatusMd = "🗄️"
                }
                foreach ($object in $issue.additionalInformation.misconfiguredObjectTypes) {
                    $resultMd += "`n| $($object) | ${issueStatusMd} | $($issue.additionalInformation.missingPermissions -join ", ") | $($issue.additionalInformation.validatedOn)"
                }
            }
        }
        $resultMd += "`n`n➡️ Open [Health issue - $($_.Name)](https://security.microsoft.com/identities/health-issues) in the Microsoft Defender portal."
        #endregion

        #region Add detailed test description
        $recommendationSteps = foreach ($recommendationStep in $_.Group[0].recommendations) {
            "$($_.Group[0].recommendations.IndexOf($recommendationStep) + 1). ${recommendationStep}"
        }
        $recommendationSteps = $recommendationSteps -join "`n`n"

        $relatedLinksMd = "* [Microsoft Defender for Identity health issues](https://learn.microsoft.com/en-us/defender-for-identity/health-alerts)", "* [Health issues - Microsoft Defender](https://security.microsoft.com/identities/health-issues)"
        $relatedLinksMd = $relatedLinksMd -join "`n"

        if ($_.Group.additionalInformation) {
            $description = $_.Group[0].description
        }
        $descriptionMd = $_.Name + "`n`n" + $description + "`n`n" + $additionalInformation + "`n`n#### Remediation actions:`n`n" + $recommendationSteps + "`n`n#### Related links:`n`n" + $relatedLinksMd
        #endregion

        Add-MtTestResultDetail -Description $descriptionMd -Result $resultMd -Severity $_.Group[0].severity

        $result | Should -Be $true -Because $_.Name
    }
}