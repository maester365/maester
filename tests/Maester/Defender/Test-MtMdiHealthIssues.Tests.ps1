BeforeDiscovery {
    $checkid = "MT.1059"

    try {
        $MdiSecurityApiError = $null
        $MdiAllHealthIssues = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'security/identities/healthIssues' -OutputType Hashtable -ErrorVariable MdiSecurityApiError
    } catch {
        Write-Verbose "Authentication needed. Please call Connect-MgGraph."
        return $null
    }

    if ($MdiSecurityApiError -match "Tenant is not onboarded to Microsoft Defender for Identity") {
        Add-MtTestResultDetail -TestName "$($checkid): MDI Health issues should be resolved" -Severity "Medium" -Description "This test checks for health issues in Microsoft Defender for Identity. The tenant is not onboarded to Microsoft Defender for Identity, so no health issues can be retrieved." -SkippedBecause 'Custom' -SkippedCustomReason 'Tenant is not onboarded to Microsoft Defender for Identity'
        return $null
    }
    if (($MdiAllHealthIssues | Where-Object { $_.status -ne "closed" } | Measure-Object) -eq 0) {
        Add-MtTestResultDetail -TestName "$($checkid): MDI Health issues should be resolved" -Severity "Medium" -Description "This test checks for health issues in Microsoft Defender for Identity" -SkippedBecause "Custom" -SkippedCustomReason "No health issues found"
        return $null
    }

    $MdiHealthIssues = [System.Collections.Generic.List[Object]]::new()

    # Add domainNames and sensorDNSNames as string properties to identify unique health issues
    $MdiAllHealthIssues | ForEach-Object {
        $_ | Add-Member -NotePropertyName 'domainNamesString' -NotePropertyValue ($_.domainNames -join ',') -Force
        $_ | Add-Member -NotePropertyName 'sensorDNSNamesString' -NotePropertyValue ($_.sensorDNSNames -join ',') -Force
    }

    # Get unique health issues (duplicated entries will be created when status of an issue has been changed)
    $MdiAllHealthIssues | Group-Object -Property displayName, domainNamesString, sensorDNSNamesString | ForEach-Object {
        $UniqueHealthIssue = $_.Group | Sort-Object -Property createdDateTime | Select-Object -First 1

        # Add the displayName to the health issue to avoid confusion of same health issue name
        if ($UniqueHealthIssue.displayName -eq "Sensor stopped communicating") {
            $UniqueHealthIssue.displayName = $UniqueHealthIssue.displayName + " - " + $UniqueHealthIssue.sensorDNSNames
        }
        $MdiHealthIssues.Add($UniqueHealthIssue) | Out-Null
    }

    $MdiHealthActiveIssues = $MdiHealthIssues | Where-Object { $_.status -ne "closed" }
}

Describe "Defender for Identity health issues" -Tag "Maester", "Defender", "Security", "All", "MDI" -ForEach $MdiHealthActiveIssues {
    It "MT.1059: MDI Health Issues - <displayName>. See https://maester.dev/docs/tests/MT.1058" -Tag "MT.1058", "Severity:Medium", $displayName {

        $issueUrl = "https://security.microsoft.com/identities/health-issues"
        $recommendationLinkMd = "`n`n➡️ Open [Health issue - $displayName]($issueUrl) in the Microsoft Defender portal."
        $testTitle = "MT.1059.$($id): MDI Health Issues - $displayName"

        if ( $status -match "dismissed" -or $status -match "suppressed" ) {
            Add-MtTestResultDetail -TestTitle $testTitle -Description $description -SkippedBecause Custom -SkippedCustomReason "This health issue has been **suppressed** by an administrator.`n`nIf this issue is valid for your MDI instance, you can change it's state from **suppressed** to **Re-open**. $recommendationLinkMd"
            return $null
        }

        #region Add detailed test description
        $actionSteps = $recommendations | ForEach-Object {
            "- " + $_
        }
        $actionSteps = $actionSteps -join "`n`n"

        #
        $affectedItems = $additionalInformation | ForEach-Object {
            "- " + $_
        }
        $affectedItems = $affectedItems -join "`n`n"

        $ResultMarkdown = $description + "`n`n" + $affectedItems + "`n`n#### Remediation actions:`n`n" + $actionSteps  + "`n`n#### Issue updated:`n`n" + $lastModifiedDateTime + "`n`n#### Issue created:`n`n" + $createdDateTime
        #endregion

        Add-MtTestResultDetail -TestTitle $testTitle -Description $description -Result $ResultMarkdown

        $status | Should -Be "closed" -Because $displayName
    }
}
