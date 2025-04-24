BeforeDiscovery {
    try {
        $MdiSensorHealthIssues = Invoke-MtGraphRequest -DisableCache -ApiVersion beta -RelativeUri 'security/identities/healthIssues' -OutputType Hashtable
        Write-Verbose "Found $($MdiSensorHealthIssues.Count) Entra recommendations"
    } catch {
        Write-Verbose "Authentication needed. Please call Connect-MgGraph."
    }
}

Describe "Defender for Identity Health issues" -Tag "Maester", "Entra", "Security", "All", "MDI" -ForEach $MdiSensorHealthIssues {
    It "MT.1057: MDI Health Issues - <displayName>. See https://maester.dev/docs/tests/MT.1057" -Tag "MT.1057", $recommendationType {

        $recommendationUrl = "https://security.microsoft.com/identities/health-issues"
        $recommendationLinkMd = "`n`n➡️ Open [Health issue - $displayName]($recommendationUrl) in the Microsoft Defender portal."

        if ( $status -match "dismissed" ) {
            Add-MtTestResultDetail -Description $description -SkippedBecause Custom -SkippedCustomReason "This recommendation has been **Suppressed** by an administrator.`n`nIf this test is valid for your tenant you can change it's state from **suppressed** to **Reopen**. $recommendationLinkMd"
            return $null
        }

        #region Add detailed test description
        $ActionSteps = $recommendations | ForEach-Object {
            "- " + $_
        }
        $ActionSteps = $ActionSteps -join "`n`n"

        $ResultMarkdown = $displayName + $description + $additionalInformation + "`n`n#### Remediation actions:`n`n" + $ActionSteps  + "`n`n#### Issue updated:`n`n" + $lastModifiedDateTime + "`n`n#### Issue created:`n`n" + $createdDateTime
        Add-MtTestResultDetail -Description $description -Result $ResultMarkdown
        #endregion
        # Actual test
        $status | Should -Be "Closed" -Because $displayName
    }
}