BeforeDiscovery {
    try {
        $MdiSecurityApiError = $null
        $MdiAllHealthIssues = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'security/identities/healthIssues' -OutputType Hashtable -ErrorVariable MdiSecurityApiError
    } catch {
        Write-Verbose "Authentication needed. Please call Connect-MgGraph."
    }

    if($MdiSecurityApiError -match "Tenant is not onboarded to Microsoft Defender for Identity") {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason "Tenant is not onboarded to Microsoft Defender for Identity"
        return $null
    }
    elseif (($MdiAllHealthIssues | Where-Object { $_.status -ne "closed" } | Measure-Object) -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NoResults
        return $null
    } else {
        $MdiHealthIssues = New-Object System.Collections.ArrayList
        $MdiHealthActiveIssues = $MdiAllHealthIssues | Where-Object { $_.status -ne "closed" }

        # Get unique health issues (duplicated entries will be created when status of an issue has been changed)
        $MdiHealthActiveIssues | Group-Object -Property displayName, description, additionalInformation, healthIssueType, sensorDNSNames, severity, recommendations | ForEach-Object {
            $UniqueHealthIssue = $_.Group | Sort-Object -Property createdDateTime | Select-Object -First 1

            # Add the displayName to the health issue to avoid confusion of same health issue name
            if ($UniqueHealthIssue.displayName -eq "Sensor stopped communicating") {
                $UniqueHealthIssue.displayName = $UniqueHealthIssue.displayName + " - " + $UniqueHealthIssue.sensorDNSNames
            }
            $MdiHealthIssues.Add($UniqueHealthIssue) | Out-Null
        }
    }
}

Describe "Defender for Identity health issues" -Tag "Maester", "Entra", "Security", "All", "MDI" -ForEach $MdiHealthIssues {
    It "MT.1057: MDI Health Issues - <displayName>. See https://maester.dev/docs/tests/MT.1057" -Tag "MT.1057", $displayName {

        $issueUrl = "https://security.microsoft.com/identities/health-issues"
        $recommendationLinkMd = "`n`n➡️ Open [Health issue - $displayName]($issueUrl) in the Microsoft Defender portal."

        if ( $status -match "dismissed" -or $status -match "suppressed" ) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "This health issue has been **Suppressed** by an administrator.`n`nIf this issue is valid for your MDI instance you can change it's state from **suppressed** to **Re-open**. $recommendationLinkMd"
            return $null
        }

        #region Add detailed test description
        $ActionSteps = $recommendations | ForEach-Object {
            "- " + $_
        }
        $ActionSteps = $ActionSteps -join "`n`n"

        $ResultMarkdown = $displayName + $description + $additionalInformation + "`n`n#### Remediation actions:`n`n" + $ActionSteps  + "`n`n#### Issue updated:`n`n" + $lastModifiedDateTime + "`n`n#### Issue created:`n`n" + $createdDateTime
        Add-MtTestResultDetail -Description $description -Result $ResultMarkdown

        $status | Should -Be "closed" -Because $displayName
    }
}
